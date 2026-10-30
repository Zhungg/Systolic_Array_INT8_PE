//=============================================================================
// File    : sa_pe.v
// Project : sa_int8_45nm  (8x8 INT8 weight-stationary systolic array, gpdk045)
// Type    : Processing Element (PE) - one MAC + double-buffered weight
//
// Inspired by the weight-stationary (WS) branch of Gemmini's PE.scala:
//   * Gemmini keeps two weight registers (c1/c2). One is used by the MAC,
//     the other is being preloaded for the next tile. A "propagate" bit that
//     travels WITH the data selects which one is active.
//   * Here: w_bank0 / w_bank1 = c1 / c2, and a_bank (travelling with the
//     activation) = Gemmini's propagate bit.
//   * Removed vs. Gemmini: output-stationary mode, shift/rounding, id/last
//     tags, bias preload through the column.
//
// Dataflow inside the array (PE at row r, column c holds W[r][c]):
//
//            w (weight preload, shifts DOWN the column, N cycles)
//            |  ps_in (partial sum from the PE above)
//            v  v
//   a_in --> [ PE ] --> a_out        a  : int8 activation, moves RIGHT
//               |                    ps : int32 partial sum, moves DOWN
//               v                    ps_out = ps_in + a_in * W_active
//            ps_out, w_out
//
// Every output is registered -> each PE is exactly one pipeline stage,
// which is what makes the array "systolic" (only neighbour-to-neighbour
// wires, no long broadcast data wires).
//
// Weight loading (shift register through the column):
//   while w_load = 1, the bank selected by w_bank shifts one row down per
//   cycle: PE(r,c).bank <= PE(r-1,c).bank. After N cycles, PE(r,c) holds
//   W[r][c] if the rows of W were fed bottom row first.
//   w_load / w_bank are the same for every PE (broadcast), which is correct
//   because the whole column must shift at the same time.
//=============================================================================
`timescale 1ns/1ps

module sa_pe #(
    parameter integer DW    = 8,      // activation / weight width (signed)
    parameter integer ACC_W = 32,     // partial-sum width (signed)
    // MAC_PIPE = 1 : register the int8 x int8 product before the 32-bit add.
    //   Splits the critical path (multiply | add) in two. Every PE gets the
    //   same extra cycle, so the systolic alignment is unchanged; only the
    //   total latency grows by 1 (sa_top adjusts c_valid automatically).
    //   Fallback if Genus cannot meet 200 MHz with MAC_PIPE = 0.
    parameter integer MAC_PIPE = 0
) (
    input  wire                     clk,
    input  wire                     rst_n,
    // activation path (left -> right)
    input  wire signed [DW-1:0]     a_in,
    input  wire                     a_bank_in,   // weight bank to use for this activation
    output reg  signed [DW-1:0]     a_out,
    output reg                      a_bank_out,
    // partial-sum path (top -> bottom)
    input  wire signed [ACC_W-1:0]  ps_in,
    output reg  signed [ACC_W-1:0]  ps_out,
    // weight preload path (top -> bottom)
    input  wire        [DW-1:0]     w_in,        // from the PE above (or array top)
    input  wire                     w_load,      // shift enable (broadcast)
    input  wire                     w_bank,      // bank being loaded (broadcast)
    output wire        [DW-1:0]     w_out        // to the PE below
);

    //-------------------------------------------------------------------------
    // Double-buffered weight storage (Gemmini c1 / c2)
    //-------------------------------------------------------------------------
    reg [DW-1:0] w_bank0;
    reg [DW-1:0] w_bank1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            w_bank0 <= {DW{1'b0}};
            w_bank1 <= {DW{1'b0}};
        end else if (w_load) begin
            // only the bank being loaded shifts; the other keeps computing
            if (w_bank) w_bank1 <= w_in;
            else        w_bank0 <= w_in;
        end
    end

    // The bank being loaded is passed down -> forms the column shift register
    assign w_out = w_bank ? w_bank1 : w_bank0;

    //-------------------------------------------------------------------------
    // MAC: weight selected by the bank bit that travels with the activation
    //-------------------------------------------------------------------------
    wire signed [DW-1:0]   w_act = a_bank_in ? $signed(w_bank1) : $signed(w_bank0);
    wire signed [2*DW-1:0] prod  = a_in * w_act;          // int8 x int8 -> int16
    // explicit sign extension to the accumulator width (lint-clean)
    wire signed [ACC_W-1:0] prod_ext = {{(ACC_W-2*DW){prod[2*DW-1]}}, prod};

    // optional product register (MAC_PIPE = 1): store the 16-bit product,
    // sign-extend after the register (16 flops per PE instead of 32)
    wire signed [ACC_W-1:0] prod_add;
    generate
        if (MAC_PIPE != 0) begin : g_mac_pipe
            reg signed [2*DW-1:0] prod_q;
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) prod_q <= {(2*DW){1'b0}};
                else        prod_q <= prod;
            end
            assign prod_add = {{(ACC_W-2*DW){prod_q[2*DW-1]}}, prod_q};
        end else begin : g_mac_comb
            assign prod_add = prod_ext;
        end
    endgenerate

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_out      <= {DW{1'b0}};
            a_bank_out <= 1'b0;
            ps_out     <= {ACC_W{1'b0}};
        end else begin
            a_out      <= a_in;                // pass activation to the right
            a_bank_out <= a_bank_in;           // bank bit travels with it
            ps_out     <= ps_in + prod_add;    // 32-bit signed accumulate
        end
    end

endmodule
