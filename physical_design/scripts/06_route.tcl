#=============================================================================
# 06_route.tcl - NanoRoute + post-route setup/hold optimisation
# ALU_32b fixed hold at the end with optDesign -postRoute -setup -hold;
# here it is part of the normal flow.
#=============================================================================
source [file join $::env(PROJ_ROOT) physical_design scripts common.tcl]
read_db $DB(cts)
apply_dont_use

set_db route_design_with_timing_driven true
set_db route_design_with_si_driven true
set_db design_top_routing_layer Metal11
set_db design_bottom_routing_layer Metal1

route_design -global_detail

set_db extract_rc_engine post_route
set_db timing_analysis_type ocv
set_db timing_analysis_cppr both
opt_design -post_route -setup -hold

# final DRC clean-up of the router (ALU_32b used ecoRoute -fix_drc)
eval_legacy {ecoRoute -fix_drc}

report_stage route
write_db $DB(route)
puts "STAGE_06_ROUTE_DONE"
