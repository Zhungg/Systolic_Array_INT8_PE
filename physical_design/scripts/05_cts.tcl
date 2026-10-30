#=============================================================================
# 05_cts.tcl - clock tree (CCOpt) + post-CTS setup AND hold optimisation
# ALU_32b: create_clock_tree spec + ccopt_design + opt_design -post_cts.
# New: explicit hold fixing right after CTS (ALU hold slack was only +29 ps;
# the array has thousands of flop->flop paths with ~no logic).
#=============================================================================
source [file join $::env(PROJ_ROOT) physical_design scripts common.tcl]
read_db $DB(place)
apply_dont_use

# clock cells only from the CLK* family (balanced rise/fall)
set_db cts_buffer_cells   {CLKBUFX2 CLKBUFX3 CLKBUFX4 CLKBUFX6 CLKBUFX8 CLKBUFX12}
set_db cts_inverter_cells {CLKINVX2 CLKINVX3 CLKINVX4 CLKINVX6 CLKINVX8 CLKINVX12}
if {[catch {set_db cts_target_max_transition_time 0.15} err]} {
    puts "WARNING: cts_target_max_transition_time not set: $err"
}

create_clock_tree_spec            ;# same bare form as the lab / ALU_32b
ccopt_design -check_cts_config
ccopt_design

set C [file join $RPT clock_tree post_cts]
file mkdir $C
catch {report_clock_trees -out_file [file join $C clock_trees.rpt]}
catch {report_skew_groups -out_file [file join $C skew_groups.rpt]}   ;# -out_file form used in ALU_32b

opt_design -post_cts
opt_design -post_cts -hold
report_stage cts

write_db $DB(cts)
puts "STAGE_05_CTS_DONE"
