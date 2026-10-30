#=============================================================================
# 07_finish.tcl - fillers, signoff checks, reports, netlists, SDF, SPEF, GDS
# Commands copied from ALU_32b (Assura DRC/LVS clean). Report folders follow
# ALU_32b/physical_design/signoff/:
#   physical_verification/  power/  routing/  clock_tree/post_route/  timing/4_signoff/
#=============================================================================
source [file join $::env(PROJ_ROOT) physical_design scripts common.tcl]
read_db $DB(route)
apply_dont_use

set PV  [file join $RPT physical_verification]
set PWR [file join $RPT power]
set RTE [file join $RPT routing]
set CLK [file join $RPT clock_tree post_route]
foreach d [list $PV $PWR $RTE $CLK] { file mkdir $d }

# ---- fillers (exact ALU_32b command) ----
eval_legacy { addFiller -cell FILL64 FILL32 FILL16 FILL8 FILL4 FILL2 FILL1 -prefix FILLER -doDRC -fitGap -markFixed }
check_filler

# ---- physical verification ----
eval_legacy "verify_drc -limit 0 -report $PV/innovus_drc.rpt"
check_connectivity -type regular -out_file $PV/connectivity.rpt
check_connectivity -type special -nets {VDD VSS} -check_pg_ports -out_file $PV/pg_connectivity.rpt
if {[catch {check_process_antenna -out_file $PV/process_antenna.rpt} err]} {
    puts "WARNING check_process_antenna: $err"; catch {check_process_antenna}
}
check_place $PV/checkPlace.rpt

# OAI32X1 must be absent (Assura DRC issue found in ALU_32b)
set n_bad [llength [get_db insts -if {.base_cell.name == OAI32X1}]]
puts "OAI32X1_INSTANCES = $n_bad"

# ---- routing / clock tree summaries (ALU_32b commands) ----
eval_legacy "report_route -summary > $RTE/route_summary.rpt"
catch {report_clock_trees -out_file $CLK/clock_trees.rpt}
catch {report_skew_groups -out_file $CLK/skew_groups.rpt}

# ---- timing / power ----
report_stage final
set_db timing_enable_simultaneous_setup_hold_mode true
report_timing_summary -checks {setup hold drv clock} -expand_views -sort_by wns \
    > [file join $RPT timing 4_signoff timing_summary.rpt]
set_db timing_enable_simultaneous_setup_hold_mode false
report_power -view FUNC_SETUP_VIEW -format detailed -toggle_rate \
    -out_file $PWR/sa_top_postRoute_power_func.rpt

# total power (mW) -> used by 08_rail.tcl as set_power_data input
set fp [open $PWR/sa_top_postRoute_power_func.rpt r]; set txt [read $fp]; close $fp
if {[regexp {Total Power:\s+([0-9.eE+-]+)} $txt -> p_mw]} {
    set fo [open $PWR/total_power_mW.txt w]; puts $fo $p_mw; close $fo
    puts "TOTAL_POWER_mW = $p_mw"
}

# ---- exports ----
write_db $DB(final)

# Plain netlist (GLS, LEC) and PG-aware netlist for Assura LVS.
# ALU_32b lesson: LVS against the plain netlist gave VDD/VSS mismatches;
# "saveNetlist -phys -includePowerGround" produced the netlist that matched.
eval_legacy "saveNetlist $RES/sa_top_postroute.v"
eval_legacy "saveNetlist -phys -includePowerGround $RES/sa_top_postroute_pg.v"
set fp [open $RES/sa_top_postroute_pg.v r]; set txt [read $fp]; close $fp
puts "PG_NETLIST VDD connections = [regexp -all {\.VDD\(} $txt]"
puts "PG_NETLIST VSS connections = [regexp -all {\.VSS\(} $txt]"

# SDF: option set confirmed on this Innovus (ALU_32b handover, sec. 4.2),
# but ONE view per file. ALU_32b mixed views in one file
# (-max FUNC_SETUP / -min FUNC_HOLD) and got triplets like (0.085:0.000:0.000)
# for CK->Q, then failed SDF GLS. With one view per file, min = typ = max,
# so the MAXIMUM/MINIMUM choice in $sdf_annotate cannot pick a zero field.
foreach {tag view} {slow FUNC_SETUP_VIEW fast FUNC_HOLD_VIEW} {
    if {[catch {
        write_sdf $RES/sa_top_postroute_${tag}.sdf \
            -max_view $view -min_view $view -typical_view $view \
            -target_application verilog -gate_level_sim_model \
            -interconnect all -recompute_delaycal -recompute_parallel_arcs
    } err]} { puts "WARNING write_sdf ($tag): $err" }
}

# SPEF (Stylus replacement of legacy rcOut -spef, confirmed mapping)
if {[catch {write_parasitics -spef_file $RES/sa_top_postroute.spef} err]} {
    puts "WARNING write_parasitics: $err"
}

# ---- GDS for Assura: LVS map (pin labels on datatype 0) + merged cell GDS ----
write_stream [file join $RES sa_top_final.gds] \
    -map_file [file join $PD config streamOut_gpdk045_assura_lvs.map] \
    -merge [list $::env(STD_GDS)] \
    -mode all -unit 2000 -structure_name $DESIGN \
    -report_file $PV/streamout.rpt

puts "STAGE_07_FINISH_DONE"
