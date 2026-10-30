//=============================================================================
// File    : sa_top.v
// Project : sa_int8_45nm  (8x8 INT8 weight-stationary systolic array, gpdk045)
// Type    : TOP LEVEL for synthesis and place & route
//
// Computes  C[M x N] = A[M x N] * W[N x N]   (int8 x int8 -> int32)
//   * one row of A enters per cycle, one row of C leaves per cycle
//   * M (number of rows of A) is unlimited - a "tile" is any number of rows
//     that use the same weight bank
//
// Block diagram
//
//   w_in[N] --[in reg]--------------------------------+ (shift down columns)
//                                                      v
//   a_in[N] --[in reg]--[skew: row r delayed r]--> [ N x N sa_array ]
//                                                      |
//   c_out[N] <--[deskew: col c delayed N-1-c]----------+
//   c_valid  <--[valid pipeline, 2N-1 stages]-- a_valid
//
// Why skew / deskew?
//   PE(r,c) must see A[m][r] exactly when the partial sum of row m arrives
//   from above, i.e. at cycle t + r + c. Delaying row r by r cycles at the
//   input does that. At the bottom, column c finishes c cycles later than
//   column 0; delaying column c by N-1-c re-aligns the whole output row.
//
// Latency : 2N cycles from a_in at the port to c_out at the port
//           (1 input register + N-1 skew + N array rows... see TB / docs)
// Throughput: N*N = 64 MAC per cycle -> 12.8 GMAC/s at 200 MHz
//
// Weight protocol (double buffering, enforced by the user / testbench)
//   1. Drive w_load=1, w_bank=b for exactly N cycles, rows of W bottom row
//      first (cycle 0: W[N-1][*], ..., cycle N-1: W[0][*]).
//   2. Stream rows of A with a_bank=b. Meanwhile the OTHER bank (!b) may be
//      loaded with the next tile's weights -> loading is hidden.
//   3. Never load bank b while activations tagged with bank b are still
//      inside the array (wait 2N cycles after the last such row).
//
// Every port goes through a register (inputs) or comes from a register
// (outputs): clean I/O timing at 200 MHz, the critical path stays inside
// the PE (8x8 multiply + 32-bit add).
//
// Reset: asynchronous, active low. Scan ports (SE, scan_in_*, scan_out_*)
// are added by Genus during DFT insertion.
//=============================================================================
`timescale 1ns/1ps

module sa_top #(
    parameter integer N     = 8,
    parameter integer DW    = 8,
    parameter integer ACC_W = 32,
    parameter integer MAC_PIPE = 1    // 1 = pipelined MAC (+1 latency), see sa_pe.v
) (
    input  wire                clk,
    input  wire                rst_n,
    // activations: one row of A per cycle
    input  wire [N*DW-1:0]     a_in,       // a_in[k*8 +: 8] = A[m][k] (signed)
    input  wire                a_valid,
    input  wire                a_bank,     // weight bank used by this row
    // weights: one row of W per cycle while w_load = 1
    input  wire [N*DW-1:0]     w_in,       // w_in[c*8 +: 8] = W[r][c] (signed)
    input  wire                w_load,
    input  wire                w_bank,     // bank being loaded
    // results: one row of C per cycle
    output wire [N*ACC_W-1:0]  c_out,      // c_out[c*32 +: 32] = C[m][c] (signed)
    output wire                c_valid
);

    //=========================================================================
    // 1) Input registers
    //    Invalid rows are forced to 0 -> no useless toggling in the MACs.
    //=========================================================================
    reg [N*DW-1:0] a_q;
    reg            a_valid_q;
    reg            a_bank_q;
    reg [N*DW-1:0] w_q;
    reg            w_load_q;
    reg            w_bank_q;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_q       <= {N*DW{1'b0}};
            a_valid_q <= 1'b0;
            a_bank_q  <= 1'b0;
            w_q       <= {N*DW{1'b0}};
            w_load_q  <= 1'b0;
            w_bank_q  <= 1'b0;
        end else begin
            a_q       <= a_valid ? a_in : {N*DW{1'b0}};
            a_valid_q <= a_valid;
            a_bank_q  <= a_bank;
            w_q       <= w_in;
            w_load_q  <= w_load;
            w_bank_q  <= w_bank;
        end
    end

    //=========================================================================
    // 2) Input skew: row r delayed by r cycles (triangle of registers)
    //    Row 0: no delay. Row r: r-stage shift register of {bank, a}.
    //=========================================================================
    wire [N*DW-1:0] a_skew;
    wire [N-1:0]    bank_skew;

    genvar r, c;
    generate
        for (r = 0; r < N; r = r + 1) begin : g_skew
            if (r == 0) begin : g_nodelay
                assign a_skew[0 +: DW] = a_q[0 +: DW];
                assign bank_skew[0]    = a_bank_q;
            end else begin : g_delay
                reg [DW:0] sr [0:r-1];           // {bank, a} per stage
                integer i;
                always @(posedge clk or negedge rst_n) begin
                    if (!rst_n) begin
                        for (i = 0; i < r; i = i + 1) sr[i] <= {(DW+1){1'b0}};
                    end else begin
                        sr[0] <= {a_bank_q, a_q[r*DW +: DW]};
                        for (i = 1; i < r; i = i + 1) sr[i] <= sr[i-1];
                    end
                end
                assign a_skew[r*DW +: DW] = sr[r-1][DW-1:0];
                assign bank_skew[r]       = sr[r-1][DW];
            end
        end
    endgenerate

    //=========================================================================
    // 3) The systolic array
    //=========================================================================
    wire [N*ACC_W-1:0] ps_col;

    sa_array #(.N(N), .DW(DW), .ACC_W(ACC_W), .MAC_PIPE(MAC_PIPE)) u_array (
        .clk        (clk),
        .rst_n      (rst_n),
        .a_row      (a_skew),
        .a_bank_row (bank_skew),
        .w_col      (w_q),
        .w_load     (w_load_q),
        .w_bank     (w_bank_q),
        .ps_col     (ps_col)
    );

    //=========================================================================
    // 4) Output deskew: column c delayed by N-1-c cycles
    //    Column N-1 comes straight from the last PE register (already a flop).
    //=========================================================================
    generate
        for (c = 0; c < N; c = c + 1) begin : g_deskew
            if (c == N-1) begin : g_nodelay
                assign c_out[c*ACC_W +: ACC_W] = ps_col[c*ACC_W +: ACC_W];
            end else begin : g_delay
                localparam integer D = N - 1 - c;
                reg [ACC_W-1:0] sr [0:D-1];
                integer i;
                always @(posedge clk or negedge rst_n) begin
                    if (!rst_n) begin
                        for (i = 0; i < D; i = i + 1) sr[i] <= {ACC_W{1'b0}};
                    end else begin
                        sr[0] <= ps_col[c*ACC_W +: ACC_W];
                        for (i = 1; i < D; i = i + 1) sr[i] <= sr[i-1];
                    end
                end
                assign c_out[c*ACC_W +: ACC_W] = sr[D-1];
            end
        end
    endgenerate

    //=========================================================================
    // 5) Valid pipeline: a_valid_q -> c_valid, 2N-1 stages
    //    (N-1 skew of the last row ... see derivation in docs/SPEC.md:
    //     PE(r,c) result ready at t+r+c+1, bottom row at t+N+c,
    //     after deskew all columns at t+2N-1)
    //=========================================================================
    localparam integer VLAT = 2*N - 1 + MAC_PIPE;
    reg [VLAT-1:0] vld_sr;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) vld_sr <= {VLAT{1'b0}};
        else        vld_sr <= {vld_sr[VLAT-2:0], a_valid_q};
    end

    assign c_valid = vld_sr[VLAT-1];

endmodule
