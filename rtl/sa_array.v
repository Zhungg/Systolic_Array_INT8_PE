//=============================================================================
// File    : sa_array.v
// Project : sa_int8_45nm
// Type    : N x N grid of sa_pe (pure structure, no control)
//
//   a_row[0] -> PE(0,0) -> PE(0,1) -> ... -> PE(0,N-1)
//   a_row[1] -> PE(1,0) -> PE(1,1) -> ... -> PE(1,N-1)
//     ...         |          |                 |
//   a_row[N-1]-> PE(N-1,0)  ...            PE(N-1,N-1)
//                 |          |                 |
//              ps_col[0]  ps_col[1]   ...  ps_col[N-1]   (bottom row outputs)
//
// * Row r carries column-index k = r of A, i.e. A[m][r].
// * Column c accumulates C[m][c] = sum_r A[m][r] * W[r][c] from top to bottom.
// * The partial sum entering the top row is 0 (no bias input in this version).
// * Inputs must already be skewed (row r delayed by r cycles) - done in sa_top.
//
// Buses are flattened (Verilog-2001): element i of a bus occupies
// bits [i*WIDTH +: WIDTH].
//=============================================================================
`timescale 1ns/1ps

module sa_array #(
    parameter integer N     = 8,
    parameter integer DW    = 8,
    parameter integer ACC_W = 32,
    parameter integer MAC_PIPE = 0
) (
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire [N*DW-1:0]      a_row,       // skewed activations, one per row
    input  wire [N-1:0]         a_bank_row,  // bank bit, one per row (skewed too)
    input  wire [N*DW-1:0]      w_col,       // weight preload, one per column
    input  wire                 w_load,
    input  wire                 w_bank,
    output wire [N*ACC_W-1:0]   ps_col       // bottom-row partial sums
);

    // Inter-PE wires. Index [r][c] flattened as (r*N + c).
    wire [DW-1:0]    a_out    [0:N*N-1];
    wire             bank_out [0:N*N-1];
    wire [ACC_W-1:0] ps_out   [0:N*N-1];
    wire [DW-1:0]    w_out    [0:N*N-1];

    genvar r, c;
    generate
        for (r = 0; r < N; r = r + 1) begin : g_row
            for (c = 0; c < N; c = c + 1) begin : g_col

                wire [DW-1:0]    a_i;
                wire             bank_i;
                wire [ACC_W-1:0] ps_i;
                wire [DW-1:0]    w_i;

                // left neighbour, or array input for column 0
                // (generate-if instead of "?:" so no index -1 is ever built)
                if (c == 0) begin : g_left_edge
                    assign a_i    = a_row[r*DW +: DW];
                    assign bank_i = a_bank_row[r];
                end else begin : g_left_pe
                    assign a_i    = a_out[r*N + c - 1];
                    assign bank_i = bank_out[r*N + c - 1];
                end

                // upper neighbour, or array top for row 0
                if (r == 0) begin : g_top_edge
                    assign ps_i = {ACC_W{1'b0}};          // no bias: start from 0
                    assign w_i  = w_col[c*DW +: DW];
                end else begin : g_top_pe
                    assign ps_i = ps_out[(r-1)*N + c];
                    assign w_i  = w_out[(r-1)*N + c];
                end

                sa_pe #(.DW(DW), .ACC_W(ACC_W), .MAC_PIPE(MAC_PIPE)) u_pe (
                    .clk        (clk),
                    .rst_n      (rst_n),
                    .a_in       (a_i),
                    .a_bank_in  (bank_i),
                    .a_out      (a_out[r*N + c]),
                    .a_bank_out (bank_out[r*N + c]),
                    .ps_in      (ps_i),
                    .ps_out     (ps_out[r*N + c]),
                    .w_in       (w_i),
                    .w_load     (w_load),
                    .w_bank     (w_bank),
                    .w_out      (w_out[r*N + c])
                );
            end
        end

        // bottom row -> outputs
        for (c = 0; c < N; c = c + 1) begin : g_out
            assign ps_col[c*ACC_W +: ACC_W] = ps_out[(N-1)*N + c];
        end
    endgenerate

endmodule
