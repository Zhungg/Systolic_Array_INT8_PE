# sa_top MMMC setup for Innovus 20.1 Stylus Common UI

if {![info exists ::env(PROJ_ROOT)]} {
    error "PROJ_ROOT is not set. Source flow_config.sh before launching Innovus."
}

set root $::env(PROJ_ROOT)

# --------------------------------------------------
# 1. Timing library sets
# --------------------------------------------------
create_library_set -name LIB_SLOW \
    -timing [list $::env(LIB_SLOW)]

create_library_set -name LIB_FAST \
    -timing [list $::env(LIB_FAST)]

# --------------------------------------------------
# 2. Timing conditions: associate each library set
# --------------------------------------------------
create_timing_condition -name TC_SLOW \
    -library_sets [list LIB_SLOW]

create_timing_condition -name TC_FAST \
    -library_sets [list LIB_FAST]

# --------------------------------------------------
# 3. RC corner
# Initial implementation setup uses the verified QRC .tch
# --------------------------------------------------
create_rc_corner -name RC_QRC \
    -qrc_tech $::env(QRC_TCH)

# --------------------------------------------------
# 4. Delay corners
# --------------------------------------------------
create_delay_corner -name DC_SLOW \
    -timing_condition TC_SLOW \
    -rc_corner RC_QRC

create_delay_corner -name DC_FAST \
    -timing_condition TC_FAST \
    -rc_corner RC_QRC

# --------------------------------------------------
# 5. Constraint modes
# --------------------------------------------------
create_constraint_mode -name FUNC_MODE \
    -sdc_files [list \
        [file join $root constraints sa_top_func.sdc] \
        [file join $root constraints sa_top_func_dft.sdc]]

create_constraint_mode -name SCAN_MODE \
    -sdc_files [list \
        [file join $root constraints sa_top_scan.sdc]]

# --------------------------------------------------
# 6. Analysis views
# --------------------------------------------------
create_analysis_view -name FUNC_SETUP_VIEW \
    -constraint_mode FUNC_MODE \
    -delay_corner DC_SLOW

create_analysis_view -name FUNC_HOLD_VIEW \
    -constraint_mode FUNC_MODE \
    -delay_corner DC_FAST

create_analysis_view -name SCAN_SETUP_VIEW \
    -constraint_mode SCAN_MODE \
    -delay_corner DC_SLOW

create_analysis_view -name SCAN_HOLD_VIEW \
    -constraint_mode SCAN_MODE \
    -delay_corner DC_FAST

# --------------------------------------------------
# 7. Activate setup and hold views
# --------------------------------------------------
set_analysis_view \
    -setup [list FUNC_SETUP_VIEW SCAN_SETUP_VIEW] \
    -hold  [list FUNC_HOLD_VIEW SCAN_HOLD_VIEW]
