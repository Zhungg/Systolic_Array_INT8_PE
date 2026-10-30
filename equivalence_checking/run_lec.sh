#!/bin/bash
#=============================================================================
# run_lec.sh - RTL vs. scan-inserted netlist equivalence check (Conformal LEC)
#   ./run_lec.sh          -> sa_dft_lec.do
#   ./run_lec.sh debug    -> sa_dft_lec.do (unmapped points + stats)
# The .do files carry the placeholder @SIM_LIB_FUNC@ (functional cell models
# without timing); it is resolved from flow_config.sh into a temp file.
#=============================================================================
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ../flow_config.sh

case "${1:-}" in
    debug) DO=sa_dft_lec.do ;;
    "")    DO=sa_dft_lec.do ;;
    *)     echo "usage: $0 [debug]" >&2; exit 2 ;;
esac

mkdir -p reports
TMP=$(mktemp ./.lec_XXXXXX.do)
trap 'rm -f "$TMP"' EXIT
sed "s#@SIM_LIB_FUNC@#${SIM_LIB_FUNC}#" "$DO" > "$TMP"

lec -64 -nogui -dofile "$TMP"
