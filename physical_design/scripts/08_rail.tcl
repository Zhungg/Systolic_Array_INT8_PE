#=============================================================================
# 08_rail.tcl - Voltus static IR-drop analysis (ERA static), FUNC_SETUP_VIEW
#
# Same commands and options as the ALU_32b rail analysis
# (innovus_session_history.tcl, signoff/rail_analysis/README.md):
#   set_rail_analysis_config -method era_static -accuracy xd ...
#   set_pg_nets / set_rail_analysis_domain / set_power_pads -format xy
#   set_power_data -format area -power <W> -bias_voltage 0.9
#   report_rail -type domain
# Differences for sa_top:
#   * voltage sources: one per Metal11 ring segment (top and bottom) per net,
#     taken from the real ring geometry instead of hand-written coordinates
#   * power value read from 07_finish (report_power), not typed in
#   * limit 5 % of VDD (0.855 V / 45 mV), as in ALU_32b
# EM is NOT signed off (no foundry EM deck) - same caveat as ALU_32b.
#=============================================================================
source [file join $::env(PROJ_ROOT) physical_design scripts common.tcl]
read_db $DB(final)

set RA [file join $RPT rail_analysis static_25c]
set PP [file join $PD scripts rail_analysis]
file mkdir $RA $PP

# ---- 1. power value from 07_finish (mW -> W); fallback = design budget ----
set p_w 0.020
set f [file join $RPT power total_power_mW.txt]
if {[file exists $f]} {
    set fp [open $f r]; set p_mw [string trim [read $fp]]; close $fp
    set p_w [expr {$p_mw / 1000.0}]
} else {
    puts "WARNING: total_power_mW.txt missing - using 20 mW design budget"
}
puts "RAIL_POWER_W = $p_w"

# ---- 2. voltage sources at the middle of each Metal11 ring segment ----
# (get_obj_in_area special_wire + .net.name/.layer.name/.shape/.rect: ALU_32b)
set die [lrange [join [get_db current_design .bbox]] 0 3]
set sw_all [get_obj_in_area -obj_type special_wire -areas [list $die]]
foreach net {VDD VSS} {
    set fo [open [file join $PP sa_${net}.pp] w]
    set k 0
    foreach sw $sw_all {
        if {[get_db $sw .net.name] ne $net}        continue
        if {[get_db $sw .layer.name] ne "Metal11"} continue
        if {[get_db $sw .shape] ne "ring"}         continue
        set r [lrange [join [get_db $sw .rect]] 0 3]
        set x [expr {([lindex $r 0] + [lindex $r 2]) / 2.0}]
        set y [expr {([lindex $r 1] + [lindex $r 3]) / 2.0}]
        incr k
        puts $fo [format "%svsrc%d %.3f %.3f Metal11" $net $k $x $y]
    }
    close $fo
    puts "PADS $net = $k"
    if {$k == 0} { error "no Metal11 ring shape found for $net - check 03_power.tcl" }
}

# ---- 3. rail analysis setup (ALU_32b options) ----
set_rail_analysis_config -method era_static -accuracy xd \
    -analysis_view FUNC_SETUP_VIEW \
    -extraction_tech_file $::env(QRC_TCH) \
    -era_current_distribution placed
set_pg_nets -net VDD -voltage 0.9 -threshold 0.855
set_pg_nets -net VSS -voltage 0.0 -threshold 0.045
set_rail_analysis_domain -domain_name SA_PD -power_nets VDD -ground_nets VSS
set_power_pads -reset
set_power_pads -net VDD -format xy -file [file join $PP sa_VDD.pp]
set_power_pads -net VSS -format xy -file [file join $PP sa_VSS.pp]
set_power_data -format area -power $p_w -bias_voltage 0.9

report_rail -type domain -output_dir $RA SA_PD

puts "STAGE_08_RAIL_DONE"
