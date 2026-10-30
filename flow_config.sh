#!/bin/bash
#=============================================================================
# flow_config.sh - single place for every tool / PDK path of the project.
# Usage (from ANY stage directory):    source ../flow_config.sh
#
# Defaults match the lab server this project was built on. Every path can be
# overridden from the environment on another site, e.g.
#     PDK_ROOT=/opt/pdk LAB_DB=/opt/lab_db source flow_config.sh
#=============================================================================

# ---- 1. Cadence/Mentor tools: source the site setup only if not done yet ----
if ! command -v xrun >/dev/null 2>&1; then
    # shellcheck disable=SC1091
    source /etc/iconfig/ic.conf.rc
fi

# ---- 2. Project root = directory containing this file ----
export PROJ_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---- 3. gpdk045 / gsclib045 (master copy in /eda/PDK) ----
export PDK_ROOT=${PDK_ROOT:-/eda/PDK}
export GPDK=$PDK_ROOT/gpdk045_v_6_0
export GSCLIB=$PDK_ROOT/gsclib045_all_v4.8/gsclib045        # SVT standard cells

# Liberty - 1.0 V rail family
export LIB_SLOW=$GSCLIB/timing/slow_vdd1v0_basicCells.lib   # 0.90 V, 125 C -> setup
export LIB_FAST=$GSCLIB/timing/fast_vdd1v0_basicCells.lib   # 1.10 V,   0 C -> hold

# LEF
export LEF_TECH=$GSCLIB/lef/gsclib045_tech.lef
export LEF_MACRO=$GSCLIB/lef/gsclib045_macro.lef

# Parasitics
export QRC_TCH=$GSCLIB/qrc/qx/gpdk045.tch                  # same as lab QRC_Tech
export QRC_RCWORST=$GPDK/qrc/rcworst/qrcTechFile           # optional 2-RC-corner upgrade
export QRC_RCBEST=$GPDK/qrc/rcbest/qrcTechFile
export CAPTBL=$GPDK/soce/gpdk045.basic.CapTbl              # correct 45 nm cap table

# Layout / LVS views
export STREAM_MAP=$GPDK/soce/streamOut.map
export STD_GDS=$GSCLIB/gds/gsclib045.gds
export STD_CDL=$GSCLIB/cdl/gsclib045.cdl

# ---- 4. Lab database (reference flow + simulation models) ----
export LAB_DB=${LAB_DB:-/home/icer/LAB/RTLtoGDSII/counter_design_database_45nm}
# Cell models WITH specify blocks -> required for SDF back-annotated GLS
export SIM_LIB_TIMING=$LAB_DB/gate_level_simulation/slow_vdd1v0_basicCells.v
# Cell models WITHOUT timing (Conformal-generated) -> for LEC and Modus
export SIM_LIB_FUNC=$LAB_DB/lib/slow_vdd1v0_basiccells.v

# ---- 5. Design ----
export DESIGN=sa_top
