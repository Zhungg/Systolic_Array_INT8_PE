#!/bin/bash
#=============================================================================
# Run sa_top Genus synthesis with muxed-scan DFT in an isolated work directory.
# Existing no-DFT results in synthesis/outputs are not overwritten.
#=============================================================================
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$PROJ_ROOT/flow_config.sh" || exit 1

RUN_DIR="$SCRIPT_DIR/dft_run"

# Avoid overwriting any previous DFT run/results.
if [ -e "$RUN_DIR/outputs/sa_top_syn_dft.v" ] || [ -e "$RUN_DIR/test_scripts" ]; then
    echo "ERROR: $RUN_DIR already contains DFT outputs. Preserving existing results."
    echo "Inspect/archive that directory, then choose a new RUN_DIR before retrying."
    exit 2
fi

# Preflight the scan flop in Liberty, functional Verilog model and physical LEF.
if ! grep -q 'SDFFRHQX1' "$LIB_SLOW"; then
    echo "ERROR: SDFFRHQX1 not found in slow Liberty: $LIB_SLOW"
    exit 3
fi
if ! grep -q 'SDFFRHQX1' "$SIM_LIB_FUNC"; then
    echo "ERROR: SDFFRHQX1 not found in functional Verilog cell models: $SIM_LIB_FUNC"
    echo "Do not proceed to write_dft_atpg until the correct scan-cell model is identified."
    exit 4
fi
if ! grep -q 'SDFFRHQX1' "$LEF_MACRO"; then
    echo "ERROR: SDFFRHQX1 not found in macro LEF: $LEF_MACRO"
    exit 5
fi

echo "DFT preflight: SDFFRHQX1 found in Liberty, Verilog model, and LEF."
echo "Project: $PROJ_ROOT"
echo "Run directory: $RUN_DIR"

mkdir -p "$RUN_DIR/logs" "$RUN_DIR/reports" "$RUN_DIR/outputs"
cd "$RUN_DIR" || exit 1

genus -no_gui -batch -files "$SCRIPT_DIR/genus_dft.tcl" -log logs/genus_dft 2>&1 | tee logs/genus_dft_console.log
genus_rc=${PIPESTATUS[0]}

if [ "$genus_rc" -ne 0 ]; then
    echo "ERROR: Genus exited with status $genus_rc. See $RUN_DIR/logs/genus_dft_console.log"
    exit "$genus_rc"
fi

if ! grep -q 'SYNTHESIS_DFT_DONE' logs/genus_dft.log 2>/dev/null; then
    echo "ERROR: SYNTHESIS_DFT_DONE marker not found. Inspect Genus logs before continuing."
    exit 6
fi

if grep -qi 'This version is not authorized for use at this site' logs/genus_dft_console.log logs/genus_dft.log 2>/dev/null; then
    echo "WARNING: Genus reported a site-authorization message. Do not treat successful execution as proof of authorization; ask the EDA/site administrator to confirm."
fi

echo "RESULT: GENUS_DFT_SCRIPT_COMPLETED"
echo "Review reports in: $RUN_DIR/reports"
echo "Review netlist and ATPG handoff in: $RUN_DIR/outputs and $RUN_DIR/test_scripts"
