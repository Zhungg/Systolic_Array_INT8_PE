//=============================================================================
// File    : tb_sa_top.v
// Project : sa_int8_45nm
// Type    : SELF-CHECKING testbench for sa_top (RTL and gate-level)
//
// What is checked
//   * Every output row c_out (when c_valid=1) against a reference matrix
//     product computed inside the TB (integer arithmetic, no RTL reuse).
//   * Output ORDER and COUNT: expected rows are pushed into a FIFO when the
//     row of A is sent; every c_valid pops one; at the end the FIFO must be
//     empty (no lost / extra rows).
//   * Double buffering: the next tile's weights are loaded into the other
//     bank WHILE the current tile streams (overlap is counted and must be > 0).
//   * Bubbles: random cycles with a_valid = 0 inside a tile.
//   * Corner values: identity, all -128 x -128 (largest positive sum),
//     127 x -128 (largest negative), alternating signs.
//   * Asynchronous reset in the middle of streaming: outputs must clear at
//     once, then the array must work again after reloading weights.
//
// Protocol followed by the TB (same as documented in sa_top.v)
//   * weight load: N cycles, w_bank = b, rows of W bottom row first
//   * a tile may start streaming only after its weights are fully loaded
//   * bank b is reloaded only 2N+2 cycles after the last row that used it
//
// Macros: +define+GLS (scan ports, SE=0), +define+SDF (annotate dut.sdf),
//         +define+VCD
// Plusargs: +NTILES=<n> random tiles (default 30), +SEED=<n>
// Verdict line: *** TEST PASSED *** / *** TEST FAILED ***
//=============================================================================
`timescale 1ns/1ps

module tb_sa_top;

    localparam integer N      = 8;
    localparam integer DW     = 8;
    localparam integer ACC_W  = 32;
    localparam integer MAXT   = 64;      // max tiles
    localparam integer MAXM   = 32;      // max rows per tile
    localparam integer FIFO_D = 4096;

    //-------------------------------------------------------------------------
    // DUT
    //-------------------------------------------------------------------------
    reg                 clk, rst_n;
    reg  [N*DW-1:0]     a_in;
    reg                 a_valid, a_bank;
    reg  [N*DW-1:0]     w_in;
    reg                 w_load, w_bank;
    wire [N*ACC_W-1:0]  c_out;
    wire                c_valid;

`ifdef GLS
    // scan-inserted netlist: 8 chains created by Genus, functional mode SE=0
    sa_top dut (
        .clk(clk), .rst_n(rst_n),
        .a_in(a_in), .a_valid(a_valid), .a_bank(a_bank),
        .w_in(w_in), .w_load(w_load), .w_bank(w_bank),
        .c_out(c_out), .c_valid(c_valid),
        .SE(1'b0),
        .scan_in_0(1'b0), .scan_in_1(1'b0), .scan_in_2(1'b0), .scan_in_3(1'b0),
        .scan_in_4(1'b0), .scan_in_5(1'b0), .scan_in_6(1'b0), .scan_in_7(1'b0),
        .scan_out_0(), .scan_out_1(), .scan_out_2(), .scan_out_3(),
        .scan_out_4(), .scan_out_5(), .scan_out_6(), .scan_out_7()
    );
`else
    sa_top #(.N(N), .DW(DW), .ACC_W(ACC_W)) dut (
        .clk(clk), .rst_n(rst_n),
        .a_in(a_in), .a_valid(a_valid), .a_bank(a_bank),
        .w_in(w_in), .w_load(w_load), .w_bank(w_bank),
        .c_out(c_out), .c_valid(c_valid)
    );
`endif

`ifdef SDF
    initial $sdf_annotate("dut.sdf", tb_sa_top.dut, , "sdf.log", "MAXIMUM");
`endif
`ifdef VCD
    initial begin $dumpfile("tb_sa_top.vcd"); $dumpvars(0, tb_sa_top); end
`endif

    // 200 MHz clock: 2.5 ns half period (real delay, timescale 1ns/1ps)
    initial clk = 1'b0;
    always #2.5 clk = ~clk;

    //-------------------------------------------------------------------------
    // Test data storage (flattened 3-D arrays)
    //   A_mem[t][m][k] -> A_mem[(t*MAXM + m)*N + k]
    //   W_mem[t][r][c] -> W_mem[(t*N + r)*N + c]
    //-------------------------------------------------------------------------
    reg signed [7:0] A_mem [0:MAXT*MAXM*N-1];
    reg signed [7:0] W_mem [0:MAXT*N*N-1];
    integer          M_of  [0:MAXT-1];        // rows in tile t

    // Expected-row FIFO
    reg [N*ACC_W-1:0] exp_fifo [0:FIFO_D-1];
    integer wp, rp;

    // statistics
    integer n_rows_chk, n_err, n_overlap, n_bubbles, n_rst_err, cycle;
    integer seed;

    //-------------------------------------------------------------------------
    // Reference model: one row of C for tile t, row m
    //-------------------------------------------------------------------------
    function [N*ACC_W-1:0] ref_row;
        input integer t;
        input integer m;
        integer k, cc;
        reg signed [ACC_W-1:0] acc;
        begin
            ref_row = {N*ACC_W{1'b0}};
            for (cc = 0; cc < N; cc = cc + 1) begin
                acc = 0;
                for (k = 0; k < N; k = k + 1)
                    acc = acc + A_mem[(t*MAXM + m)*N + k] * W_mem[(t*N + k)*N + cc];
                ref_row[cc*ACC_W +: ACC_W] = acc;
            end
        end
    endfunction

    //-------------------------------------------------------------------------
    // Output checker (called once per cycle at negedge, BEFORE driving)
    //-------------------------------------------------------------------------
    integer cc2;
    task check_output;
        begin
            if (!rst_n) begin
                if (c_valid !== 1'b0 || c_out !== {N*ACC_W{1'b0}}) begin
                    n_rst_err = n_rst_err + 1;
                    $display("[%0t] ERROR outputs not cleared during reset", $time);
                end
            end else if (c_valid === 1'b1) begin
                if (rp == wp) begin
                    n_err = n_err + 1;
                    $display("[%0t] ERROR c_valid with empty expected FIFO", $time);
                end else begin
                    n_rows_chk = n_rows_chk + 1;
                    if (c_out !== exp_fifo[rp % FIFO_D]) begin
                        n_err = n_err + 1;
                        if (n_err <= 10)
                            for (cc2 = 0; cc2 < N; cc2 = cc2 + 1)
                                $display("[%0t] ERROR row %0d col %0d : got %0d exp %0d", $time,
                                    n_rows_chk, cc2,
                                    $signed(c_out[cc2*ACC_W +: ACC_W]),
                                    $signed(exp_fifo[rp % FIFO_D][cc2*ACC_W +: ACC_W]));
                    end
                    rp = rp + 1;
                end
            end else if (c_valid !== 1'b0) begin
                n_err = n_err + 1;
                $display("[%0t] ERROR c_valid is X/Z", $time);
            end
        end
    endtask

    //-------------------------------------------------------------------------
    // Tile scheduler: weight loader + activation streamer running in the
    // same cycle loop (this is what creates the load/compute overlap).
    //-------------------------------------------------------------------------
    integer ld_tile, ld_cnt, st_tile, st_row, k2, c3;
    integer bank_free_at [0:1];   // cycle from which bank b may be reloaded
    integer ready_at     [0:MAXT-1];
    reg     loaded       [0:MAXT-1];
    integer bubble_pct;

    task run_tiles;
        input integer t0;          // first tile index
        input integer nt;          // number of tiles
        integer done;
        begin
            ld_tile = t0; ld_cnt = 0;
            st_tile = t0; st_row = 0;
            done    = 0;
            while (!done) begin
                @(negedge clk);
                cycle = cycle + 1;
                check_output;

                // defaults: idle
                a_valid = 1'b0; a_in = {N*DW{1'b0}};
                w_load  = 1'b0; w_in = {N*DW{1'b0}};

                //---------------- weight loader ----------------
                if (ld_tile < t0 + nt) begin
                    if (ld_cnt > 0 || cycle >= bank_free_at[ld_tile % 2]) begin
                        w_load = 1'b1;
                        w_bank = ld_tile % 2;
                        // bottom row first: cycle i loads row N-1-i
                        for (c3 = 0; c3 < N; c3 = c3 + 1)
                            w_in[c3*DW +: DW] = W_mem[(ld_tile*N + (N-1-ld_cnt))*N + c3];
                        ld_cnt = ld_cnt + 1;
                        if (ld_cnt == N) begin
                            loaded[ld_tile]   = 1'b1;
                            ready_at[ld_tile] = cycle + 2;
                            // bank now belongs to this tile until its last row
                            // has left the array (set again by the streamer)
                            bank_free_at[ld_tile % 2] = 32'h7FFF_FFFF;
                            ld_tile = ld_tile + 1;
                            ld_cnt  = 0;
                        end
                    end
                end

                //---------------- activation streamer ----------------
                if (st_tile < t0 + nt) begin
                    if (loaded[st_tile] && cycle >= ready_at[st_tile]) begin
                        if (({$random(seed)} % 100) < bubble_pct) begin
                            n_bubbles = n_bubbles + 1;          // bubble: a_valid = 0
                        end else begin
                            a_valid = 1'b1;
                            a_bank  = st_tile % 2;
                            for (k2 = 0; k2 < N; k2 = k2 + 1)
                                a_in[k2*DW +: DW] = A_mem[(st_tile*MAXM + st_row)*N + k2];
                            exp_fifo[wp % FIFO_D] = ref_row(st_tile, st_row);
                            wp = wp + 1;
                            if (w_load) n_overlap = n_overlap + 1;
                            st_row = st_row + 1;
                            if (st_row == M_of[st_tile]) begin
                                bank_free_at[st_tile % 2] = cycle + 2*N + 2;
                                st_tile = st_tile + 1;
                                st_row  = 0;
                            end
                        end
                    end
                end

                if (st_tile == t0 + nt && ld_tile == t0 + nt) done = 1;
            end
        end
    endtask

    task drain;     // wait until every expected row came out
        integer guard;
        begin
            guard = 0;
            while (rp != wp && guard < 8*N) begin
                @(negedge clk); cycle = cycle + 1; check_output;
                a_valid = 1'b0; w_load = 1'b0;
                guard = guard + 1;
            end
            repeat (4) begin @(negedge clk); cycle = cycle + 1; check_output; end
        end
    endtask

    //-------------------------------------------------------------------------
    // Data generators
    //-------------------------------------------------------------------------
    function signed [7:0] rnd8;
        input integer dummy;
        integer s;
        begin
            s = {$random(seed)} % 10;
            case (s)
                0: rnd8 = -8'sd128;
                1: rnd8 =  8'sd127;
                2: rnd8 =  8'sd0;
                3: rnd8 =  8'sd1;
                4: rnd8 = -8'sd1;
                default: rnd8 = $random(seed);
            endcase
        end
    endfunction

    integer t, m, k, cc;
    task gen_tile;       // kind: 0 random, 1 identity W, 2 all -128, 3 127 x -128, 4 alternating
        input integer ti;
        input integer kind;
        input integer rows;
        begin
            M_of[ti] = rows;
            loaded[ti] = 1'b0;
            for (k = 0; k < N; k = k + 1)
                for (cc = 0; cc < N; cc = cc + 1)
                    case (kind)
                        1: W_mem[(ti*N + k)*N + cc] = (k == cc) ? 8'sd1 : 8'sd0;
                        2: W_mem[(ti*N + k)*N + cc] = -8'sd128;
                        3: W_mem[(ti*N + k)*N + cc] = -8'sd128;
                        4: W_mem[(ti*N + k)*N + cc] = ((k + cc) % 2) ? 8'sd127 : -8'sd128;
                        default: W_mem[(ti*N + k)*N + cc] = rnd8(0);
                    endcase
            for (m = 0; m < rows; m = m + 1)
                for (k = 0; k < N; k = k + 1)
                    case (kind)
                        2: A_mem[(ti*MAXM + m)*N + k] = -8'sd128;
                        3: A_mem[(ti*MAXM + m)*N + k] =  8'sd127;
                        4: A_mem[(ti*MAXM + m)*N + k] = (k % 2) ? -8'sd128 : 8'sd127;
                        default: A_mem[(ti*MAXM + m)*N + k] = rnd8(0);
                    endcase
        end
    endtask

    //-------------------------------------------------------------------------
    // Main
    //-------------------------------------------------------------------------
    integer ntiles, i;
    reg [N*ACC_W-1:0] kat_row;
    initial begin
        if (!$value$plusargs("NTILES=%d", ntiles)) ntiles = 30;
        if (!$value$plusargs("SEED=%d",   seed))   seed   = 1;
        if (ntiles > MAXT - 8) ntiles = MAXT - 8;
        $display("[TB] N=%0d NTILES=%0d SEED=%0d", N, ntiles, seed);

        n_rows_chk = 0; n_err = 0; n_overlap = 0; n_bubbles = 0; n_rst_err = 0;
        wp = 0; rp = 0; cycle = 0;
        bank_free_at[0] = 0; bank_free_at[1] = 0;

        // ---- known-answer check of the reference model ----
        gen_tile(0, 2, 1);                     // -128 x -128, 8 terms
        kat_row = ref_row(0, 0);
        if ($signed(kat_row[ACC_W-1:0]) !== 32'sd131072) begin
            n_err = n_err + 1; $display("KAT ERROR: 8 x (-128 x -128) != 131072");
        end
        gen_tile(0, 3, 1);                     // 127 x -128, 8 terms
        kat_row = ref_row(0, 0);
        if ($signed(kat_row[ACC_W-1:0]) !== -32'sd130048) begin
            n_err = n_err + 1; $display("KAT ERROR: 8 x (127 x -128) != -130048");
        end

        // ---- reset ----
        rst_n = 1'b0; a_in = 0; a_valid = 0; a_bank = 0; w_in = 0; w_load = 0; w_bank = 0;
        repeat (3) begin @(negedge clk); check_output; end
        rst_n = 1'b1;

        // ---- phase 1: directed tiles, no bubbles ----
        bubble_pct = 0;
        gen_tile(0, 1, 8);                     // identity  -> C = A
        gen_tile(1, 2, 4);                     // max positive
        gen_tile(2, 3, 4);                     // max negative
        gen_tile(3, 4, 6);                     // alternating signs
        gen_tile(4, 0, 1);                     // 1-row tile (short)
        gen_tile(5, 0, 2);
        run_tiles(0, 6);
        drain;
        $display("[TB] phase 1 (directed) done: %0d rows checked", n_rows_chk);

        // ---- phase 2: random tiles, random sizes, 20 %% bubbles ----
        bubble_pct = 20;
        for (i = 0; i < ntiles; i = i + 1)
            gen_tile(6 + i, 0, 1 + ({$random(seed)} % MAXM));
        run_tiles(6, ntiles);
        drain;
        $display("[TB] phase 2 (random) done: %0d rows checked", n_rows_chk);

        // ---- phase 3: async reset while streaming, then recover ----
        t = 6 + ntiles;
        gen_tile(t, 0, MAXM);
        bubble_pct = 0;
        fork : rst_test
            run_tiles(t, 1);
            begin
                repeat (3*N + 10) @(negedge clk);    // outputs are flowing by now
                #1.0 rst_n = 1'b0;                 // between clock edges
                #0.5;
                if (c_valid !== 1'b0 || c_out !== {N*ACC_W{1'b0}}) begin
                    n_rst_err = n_rst_err + 1;
                    $display("[%0t] ERROR async reset did not clear outputs", $time);
                end
                disable rst_test;
            end
        join
        rp = wp;                                   // results in flight are lost by design
        a_valid = 0; w_load = 0;
        @(negedge clk); check_output;
        rst_n = 1'b1;
        bank_free_at[0] = 0; bank_free_at[1] = 0;
        $display("[%0t] [TB] async reset test done", $time);
        gen_tile(t + 1, 0, 12);
        gen_tile(t + 2, 4, 5);
        run_tiles(t + 1, 2);
        drain;

        // ---- report ----
        $display("--------------------------------------------------------");
        $display(" sa_top self-checking testbench summary");
        $display("--------------------------------------------------------");
        $display("   output rows checked : %0d (x %0d results)", n_rows_chk, N);
        $display("   rows still expected : %0d", wp - rp);
        $display("   load/compute overlap: %0d cycles", n_overlap);
        $display("   bubbles injected    : %0d", n_bubbles);
        $display("   data errors         : %0d", n_err);
        $display("   reset errors        : %0d", n_rst_err);
        if (n_overlap == 0) begin
            n_err = n_err + 1; $display("   COVERAGE HOLE: double buffering never exercised");
        end
        if (n_err == 0 && n_rst_err == 0 && wp == rp && n_rows_chk > 0)
            $display("*** TEST PASSED ***");
        else
            $display("*** TEST FAILED ***");
        $display("--------------------------------------------------------");
        $finish;
    end

    // watchdog
    initial begin
        #2000000;
        $display("*** TEST FAILED *** (watchdog timeout)");
        $finish;
    end

endmodule
