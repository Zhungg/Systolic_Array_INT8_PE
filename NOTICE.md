# Notice

The original work in this repository (RTL, testbench, constraints, scripts and
documentation) is licensed under the [Apache License 2.0](LICENSE).

## Not included, not covered by this license

- **Cadence tools** (Genus, Innovus, Modus, Xcelium, IMC, Conformal LEC, Virtuoso,
  Assura, Voltus). A valid Cadence license is required to run the flow.
- **Cadence GPDK045 and gsclib045** (Liberty `.lib`, LEF, GDS, CDL, QRC tech files,
  CapTbl, cell Verilog models). They are distributed by Cadence under their own terms and
  are deliberately **not** part of this repository. Obtain them from your own
  licensed installation and point `flow_config.sh` at them.

## Generated files that reference the PDK

Files produced by the flow (gate-level netlists, SDF, SCANDEF, post-route
netlists, `streamOut_*.map` layer maps) reference gsclib045 cell names or PDK layer
numbers. They are published as design-flow evidence only; no cell layout, timing
library or other PDK content is reproduced.

If you are a rights holder and believe any file here should be removed, please open an
issue.

## Trademarks

Cadence, Genus, Innovus, Modus, Xcelium, Virtuoso and Assura are trademarks of
Cadence Design Systems, Inc. RISC-V is a trademark of RISC-V International. This
project is independent and not affiliated with or endorsed by either.
