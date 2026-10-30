# Physical-design signoff evidence

Curated copies of the reports written by `physical_design/run_pnr.sh` (stages 04–08).
The raw `physical_design/reports/` tree is git-ignored; gzipped Innovus reports were
expanded here (final run, after the 72-buffer LVS fix), and the duplicate `*_all` / `*_default` timing path dumps were dropped
(`*_reg2reg` is kept).

| Folder | Stage | Key result |
| :--- | :--- | :--- |
| `timing/1_place_opt/` | 04 place | setup WNS +0.365 ns, 0 DRV, overflow 0 % |
| `timing/2_post_cts/` | 05 CTS + hold opt | setup +0.375 ns, hold +0.017 ns |
| `timing/3_post_route/` | 06 route + opt (OCV, SI, CPPR) | setup +0.564 ns, hold +0.016 ns |
| `timing/4_signoff/` | 07 finish | `timing_summary.rpt`: all four views, 0 violating paths |
| `clock_tree/` | 05 / 07 | 48 clock buffers, skew 28 ps (func, slow corner) |
| `physical_verification/` | 03 / 07 | Innovus DRC 0, connectivity clean, PG clean, antenna 0 (also `process_antenna_interactive_check.rpt`) |
| `power/` | 07 | 6.94 mW (internal 77 %, switching 23 %, leakage 0.02 %) |
| `routing/` | 07 | total net length ≈ 322 mm |
| `rail_analysis/static_25c/` | 08 Voltus | VDD drop ≈ 2 mV, VSS bounce 1.53 mV (limit 45 mV) |

`physical_verification/pg_connectivity_after_powerplan.rpt` lists 406 `IMPVFC-94`
"dangling wire" infos: these are the open ends of the Metal1 follow-pin rails at the
core edges (the ring is on Metal10/11). The final `pg_connectivity.rpt` is clean and
Voltus reports 0 weakly connected or floating instances.
