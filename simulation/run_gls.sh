#!/bin/bash
#=============================================================================
# run_gls.sh - gate-level simulation of the scan-inserted netlist (SE = 0)
#   ./run_gls.sh syn                post-synthesis netlist, zero delay
#   ./run_gls.sh syn   sdf          post-synthesis netlist + Genus SDF
#   ./run_gls.sh route              post-route netlist, zero delay   (control run)
#   ./run_gls.sh route sdf slow     post-route + Innovus SDF, FUNC_SETUP_VIEW
#   ./run_gls.sh route sdf fast     post-route + Innovus SDF, FUNC_HOLD_VIEW
#
# Lessons from ALU_32b (handover 2026-10-30):
#   * Always run the zero-delay control first; only then the SDF run.
#   * xrun exits with 0 even when the testbench fails -> the verdict is the
#     "*** TEST PASSED/FAILED ***" line, checked below.
#   * $sdf_annotate uses the relative name "dut.sdf" -> each run gets its own
#     directory containing a dut.sdf link (no stale SDF from an older run).
#   * Post-route SDFs are written with ONE view per file (07_finish.tcl), so
#     the "MAXIMUM" field of every triplet holds a real delay.
#=============================================================================
source ../flow_config.sh
STAGE=${1:-syn}
USE_SDF=${2:-}
CORNER=${3:-slow}

case "$STAGE" in
  syn)   NET=$PROJ_ROOT/synthesis/dft_run/outputs/sa_top_syn_dft.v
         SDF=$PROJ_ROOT/synthesis/dft_run/outputs/sa_top_dft_delays.sdf ;;
  route) NET=$PROJ_ROOT/physical_design/results/sa_top_postroute.v
         SDF=$PROJ_ROOT/physical_design/results/sa_top_postroute_${CORNER}.sdf ;;
  *) echo "usage: $0 syn|route [sdf [slow|fast]]"; exit 2 ;;
esac
[ -f "$NET" ] || { echo "netlist not found: $NET"; exit 3; }

RUN=gls_${STAGE}${USE_SDF:+_sdf_${CORNER}}
rm -rf "$RUN"; mkdir -p "$RUN"; cd "$RUN" || exit 1

DEFS="+define+GLS"
if [ "$USE_SDF" = "sdf" ]; then
    [ -f "$SDF" ] || { echo "SDF not found: $SDF"; exit 4; }
    ln -sf "$SDF" dut.sdf
    DEFS="$DEFS +define+SDF"
fi

xrun -64bit -access +rwc -timescale 1ns/1ps $DEFS \
     -v $SIM_LIB_TIMING $NET $PROJ_ROOT/tb/tb_sa_top.v \
     -top tb_sa_top +NTILES=10 \
     -l xrun.log

echo "------------------------------------------------------------ $RUN"
grep -E "Annotation completed|No. of Pathdelays|No. of Tchecks" xrun.log sdf.log 2>/dev/null | head
echo "timing-check violations reported by the simulator:"
grep -cE "\\\$setuphold|\\\$hold|\\\$recovery|\\\$removal|\\\$width|Timing violation" xrun.log
grep -E "TEST (PASSED|FAILED)" xrun.log || echo "NO VERDICT LINE - simulation did not finish"
