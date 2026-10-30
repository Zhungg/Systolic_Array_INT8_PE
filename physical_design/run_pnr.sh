#!/bin/bash
#=============================================================================
# run_pnr.sh - Innovus batch flow, one stage per call (or all)
#   ./run_pnr.sh 01        import            -> results/sa_01_init.enc
#   ./run_pnr.sh 02        floorplan + pins
#   ./run_pnr.sh 03        power grid
#   ./run_pnr.sh 04        place + tie cells
#   ./run_pnr.sh 05        CTS + post-CTS setup/hold opt
#   ./run_pnr.sh 06        route + post-route setup/hold opt
#   ./run_pnr.sh 07        fillers, checks, reports, netlist, SDF, GDS
#   ./run_pnr.sh 08        Voltus static IR drop (optional, after 07)
#   ./run_pnr.sh all       01..08 in sequence, stops at the first failure
# Open any stage DB in the GUI (via VNC):
#   innovus -stylus   then   read_db results/sa_05_cts.enc
#=============================================================================
set -o pipefail
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
source ../flow_config.sh || exit 1
mkdir -p logs results reports

run_stage() {
    local n=$1
    local f
    f=$(ls scripts/${n}_*.tcl 2>/dev/null | head -1)
    [ -z "$f" ] && { echo "No script for stage $n"; exit 2; }
    local name
    name=$(basename "$f" .tcl)
    echo "=== $(date +%H:%M:%S) start $name"
    innovus -stylus -no_gui -batch -files "$f" -log "logs/$name" 2>&1 | tail -5
    if ! grep -q "STAGE_${n}_.*_DONE" "logs/$name.log" 2>/dev/null; then
        echo "*** $name FAILED - see physical_design/logs/$name.log (grep -n ERROR)"
        exit 3
    fi
    echo "=== $(date +%H:%M:%S) done  $name"
}

if [ "$1" = "all" ]; then
    for s in 01 02 03 04 05 06 07 08; do run_stage $s; done
else
    run_stage "${1:?usage: $0 01..08|all}"
fi
