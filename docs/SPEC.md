# sa_top — 8×8 INT8 weight-stationary systolic array: specification

## Function
`C[M×8] = A[M×8] × W[8×8]`, int8 × int8 → int32. One row of A enters per
cycle, one row of C leaves per cycle; M is unlimited.

## Parameters (frozen)
| Item | Value |
|---|---|
| Array | N = 8 (64 PEs), parameterised · optional pipelined MAC (`MAC_PIPE`) |
| Data | A, W: signed int8 · partial sums / outputs: signed int32 |
| Clock | 200 MHz functional (5 ns) · 20 MHz scan shift (50 ns) |
| Reset | asynchronous, active low |
| DFT | muxed scan, 8 chains (`scan_in_i` → `scan_out_i`), `SE` |
| Library | gsclib045 SVT, slow_vdd1v0 (setup) / fast_vdd1v0 (hold), `OAI32X1` dont_use |
| Latency | 2N = 16 cycles (port to port) |
| Throughput | 64 MAC / cycle = 12.8 GMAC/s @ 200 MHz |

## Microarchitecture
```
           w_in[0..7]  (weight preload: shifts DOWN the columns, 8 cycles)
              |    |         |
a_in[0] -[reg]-> PE00 -> PE01 -> ... -> PE07      a  (int8)  moves RIGHT
a_in[1] -[reg]-[1 skew]-> PE10 -> ...  -> PE17    ps (int32) moves DOWN
  ...                                             W[r][c] stays in PE(r,c)
a_in[7] -[reg]-[7 skew]-> PE70 -> ...  -> PE77
                           |               |
                    [deskew: column c delayed 7-c] -> c_out[0..7], c_valid
```

**PE** (inspired by the WS branch of Gemmini `PE.scala`):
`ps_out = ps_in + a_in × W[a_bank]`, all outputs registered.
- Two weight registers per PE (Gemmini `c1/c2`): one used by the MAC, the
  other being preloaded → weight loading is hidden behind computation.
- The bank-select bit travels with the activation (Gemmini `propagate`), so
  each PE switches bank exactly when the first row of a new tile reaches it.
- Not implemented (vs Gemmini): output-stationary mode, shift/rounding,
  bias preload, id/last tags.

**Timing derivation.** With the input registered at cycle t, PE(r,c) sees
`A[m][r]` at t+r+c, exactly when the partial sum of row m arrives from PE(r-1,c).
Bottom row column c is ready at t+N+c; deskew adds N-1-c → all columns at t+2N-1;
plus the input register → 2N cycles port to port.

## Interface
| Port | Dir | Width | Description |
|---|---|---|---|
| `clk`, `rst_n` | in | 1 | clock, async active-low reset |
| `a_in` | in | 64 | row of A, `a_in[k*8 +: 8] = A[m][k]` |
| `a_valid` | in | 1 | row valid (invalid rows are zeroed at the input) |
| `a_bank` | in | 1 | weight bank used by this row |
| `w_in` | in | 64 | row of W, `w_in[c*8 +: 8] = W[r][c]` |
| `w_load` | in | 1 | shift weights down one row |
| `w_bank` | in | 1 | bank being loaded |
| `c_out` | out | 256 | row of C, `c_out[c*32 +: 32] = C[m][c]` |
| `c_valid` | out | 1 | `c_out` valid |
| `SE`, `scan_in_0..7`, `scan_out_0..7` | — | — | added by Genus DFT |

## Weight protocol (double buffering)
1. `w_load=1, w_bank=b` for exactly 8 cycles, rows of W **bottom row first**.
2. Stream rows of A with `a_bank=b` (from 2 cycles after the last load cycle);
   meanwhile load the next tile into bank `!b`.
3. Do not reload bank b until 2N+2 cycles after the last row that used it.

## Verification
Self-checking TB (`tb/tb_sa_top.v`): reference matrix product, expected-row FIFO
(order + count), directed tiles (identity, −128×−128, 127×−128, alternating),
random tiles of random height with 20 % bubbles, load/compute overlap counter,
async reset during streaming + recovery. Same TB for gate level (`+define+GLS`,
`+define+SDF`).
