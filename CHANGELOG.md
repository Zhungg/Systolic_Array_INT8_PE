# Changelog

## v1.1 (2026-10-31) - first full RTL-to-GDSII run, DRC + LVS clean
- RTL: `MAC_PIPE` default 0 -> 1. Genus WNS with the single-cycle MAC was +5 ps
  (decision point: < +0.3 ns); with the product register it is +875 ps.
- Genus: `read_hdl -sv` (a `localparam` inside a generate block is SystemVerilog, VLOGPT-9).
- LEC: Genus merges 1 122 sign-extension flops (GLO-42), so a single RTL -> DFT-netlist
  compare reports false non-equivalences. Replaced by the two-stage Cadence flow:
  RTL -> `fv_map` with the Genus-generated dofile (`lec -xl`), then `fv_map` -> DFT netlist
  (`sa_fvmap_dft_lec.do`). Both stages pass.
- Innovus 06: `timing_analysis_type ocv` + `timing_analysis_cppr both` before
  `opt_design -post_route` (IMPOPT-6080: SI-aware optimisation requires OCV).
- Innovus 03: Metal10 stripe spacing 0.5 -> 1.5 um (18 ParallelRunLength spacing
  violations; LEF requires 1.25 um for W >= 0.75 um, PRL >= 3.5 um).
- Assura LVS: the sign-extended `c_out` bits shared one net through 72 `assign`s
  (64 pin-label shorts). `physical_design/scripts/remove_assigns.awk` turns them into
  `BUFX2` port buffers (`dont_touch`), read by `01_init.tcl`. LVS now matches.
  `setDoAssign on -buffer` through `eval_legacy` had no effect in Stylus mode.
- Final layout: setup +0.564 ns, hold +0.016 ns, Innovus DRC 0, antenna 0,
  IR drop ~2 mV, 6.94 mW.

## v1.0 (2026-10-30) - frozen baseline for the 10 h RTL-to-GDSII run
- RTL: sa_pe / sa_array / sa_top, 8x8 INT8 WS, double-buffered weights, MAC_PIPE option.
- TB: self-checking, expected-row FIFO, double-buffer overlap, bubbles, async reset.
- SDC: 200 MHz func, func DFT add-on, 20 MHz scan.
- Genus DFT (8 chains, OAI32X1 dont_use), Conformal LEC, Modus ATPG wrappers.
- Innovus batch 01..08 (init, floorplan + computed pin pitch, power, place, CTS + hold,
  route + hold, finish/export/GDS, Voltus static IR).
- Report tree aligned with ALU_32b `physical_design/signoff/`.
- From the ALU_32b handover: PG netlist via `saveNetlist -phys -includePowerGround`,
  one-view-per-file SDF export, GLS verdict from the testbench line, no standalone Tempus
  (licence features missing).
