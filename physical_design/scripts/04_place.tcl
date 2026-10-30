#=============================================================================
# 04_place.tcl - scan DEF, placement + pre-CTS optimisation, tie cells
#=============================================================================
source [file join $::env(PROJ_ROOT) physical_design scripts common.tcl]
read_db $DB(pwr)
apply_dont_use

# Scan chains from Genus -> Innovus may reorder them by placement
read_def [file join $ROOT synthesis dft_run outputs sa_top_scanDEF.scandef]
set_db reorder_scan_comp_logic true

file mkdir [file join $RPT timing 1_place_opt]
place_opt_design -report_dir [file join $RPT timing 1_place_opt] -report_prefix sa_place_opt

# constant pins -> TIEHI / TIELO cells (not direct VDD/VSS connections)
set_db add_tieoffs_cells {TIEHI TIELO}
add_tieoffs

set P [file join $RPT timing 1_place_opt]
check_place [file join $P check_place.rpt]
report_congestion -overflow                 > [file join $P congestion.rpt]
report_congestion -hotspot -num_hotspot 10 >> [file join $P congestion.rpt]
report_stage place

write_db $DB(place)
puts "STAGE_04_PLACE_DONE"
