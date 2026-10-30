#=============================================================================
# common.tcl - shared settings for every Innovus stage script (sourced first)
# Commands in the stage scripts are taken from ALU_32b
# (physical_design/scripts/innovus_session_history.tcl), i.e. already proven
# on this machine with Innovus 20.10 Stylus.
#=============================================================================
if {![info exists ::env(PROJ_ROOT)]} {
    error "PROJ_ROOT is not set. Run through run_pnr.sh (sources flow_config.sh)."
}
set ROOT   $::env(PROJ_ROOT)
set PD     [file join $ROOT physical_design]
set RES    [file join $PD results]
set RPT    [file join $PD reports]
set DESIGN $::env(DESIGN)
file mkdir $RES $RPT

# 4 cores of the 12 available; RAM (7.6 GB) is the real limit
set_multi_cpu_usage -local_cpu 4

# Stage databases (each stage reads the previous one)
set DB(init)  [file join $RES sa_01_init.enc]
set DB(fp)    [file join $RES sa_02_floorplan.enc]
set DB(pwr)   [file join $RES sa_03_power.enc]
set DB(place) [file join $RES sa_04_place.enc]
set DB(cts)   [file join $RES sa_05_cts.enc]
set DB(route) [file join $RES sa_06_route.enc]
set DB(final) [file join $RES sa_07_final.enc]

# Re-applied after every read_db (attribute is not always saved)
proc apply_dont_use {} {
    if {[catch {set_db [get_db base_cells OAI32X1] .dont_use true} err]} {
        puts "WARNING: could not set dont_use on OAI32X1: $err"
    } else {
        puts "DONT_USE OAI32X1 = [get_db [get_db base_cells OAI32X1] .dont_use]"
    }
}

# Timing reports, same folder layout as ALU_32b/physical_design/signoff/timing:
#   1_place_opt / 2_post_cts / 3_post_route / 4_signoff
proc report_stage {stage} {
    global RPT
    array set dir  {place 1_place_opt cts 2_post_cts route 3_post_route final 4_signoff}
    array set mode {place -pre_cts    cts -post_cts  route -post_route  final -post_route}
    set d [file join $RPT timing $dir($stage)]
    file mkdir $d
    time_design $mode($stage) -path_report -slack_report -drv_report -num_paths 10 \
        -report_dir $d -report_prefix sa_${stage}_setup
    if {$stage ne "place"} {
        time_design $mode($stage) -hold -path_report -slack_report -num_paths 10 \
            -report_dir $d -report_prefix sa_${stage}_hold
    }
}
