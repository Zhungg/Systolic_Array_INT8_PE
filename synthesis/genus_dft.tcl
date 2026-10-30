#=============================================================================
# genus_dft.tcl -- sa_top (8x8 INT8 systolic array) synthesis + muxed-scan DFT
# Based on ALU_32b/synthesis/genus_dft.tcl (proven on Genus 20.10, gsclib045)
# Changes vs ALU: 3 RTL files, 200 MHz SDC, OAI32X1 dont_use, 8 scan chains,
#                 power report, hierarchy summary.
# Run from synthesis/dft_run via run_synth_dft.sh
#=============================================================================

file mkdir outputs
file mkdir reports

# 1. Library, RTL, elaboration ------------------------------------------------
set_db init_lib_search_path $env(GSCLIB)/timing
set_db init_hdl_search_path $env(PROJ_ROOT)/rtl
set_db hdl_error_on_blackbox true

read_libs $env(LIB_SLOW)

# OAI32X1: its layout has an internal DRC error in Assura (found in ALU_32b).
# Forbid it from the start instead of an ECO swap at the end of the flow.
set bad_cells [get_db lib_cells */OAI32X1]
if {[llength $bad_cells] == 0} { error "OAI32X1 not found in library - check name" }
set_db $bad_cells .dont_use true
puts "DONT_USE set on: [get_db $bad_cells .name]"

read_hdl -sv {sa_pe.v sa_array.v sa_top.v}
elaborate $env(DESIGN)
check_design -all > reports/pre_synth_check_design.rpt

# 2. Functional constraints (scan ports do not exist yet) ---------------------
read_sdc $env(PROJ_ROOT)/constraints/sa_top_func.sdc
check_timing_intent -verbose > reports/pre_synth_timing_intent.rpt

# 3. DFT setup -----------------------------------------------------------------
set_db dft_scan_style muxed_scan
set_db dft_prefix dft_
define_test_signal -function shift_enable -name SE -active high -create_port SE
check_dft_rules > reports/dft_rules_pre_synthesis.rpt

# 4. Synthesis -----------------------------------------------------------------
set_db syn_generic_effort medium
syn_generic
set_db syn_map_effort high
syn_map
set_db syn_opt_effort high

check_dft_rules > reports/dft_rules_post_mapping.rpt

# 5. 8 balanced scan chains (~4.4k flops -> ~560 per chain) -------------------
#    Port names scan_in_<i> / scan_out_<i> are used by the SDCs, the TB (GLS)
#    and the LEC dofile - keep them consistent.
set NCHAIN 8
set_db design:$env(DESIGN) .dft_min_number_of_scan_chains $NCHAIN
for {set i 0} {$i < $NCHAIN} {incr i} {
    define_scan_chain -name chain_$i -sdi scan_in_$i -sdo scan_out_$i -create_ports
}
connect_scan_chains -auto_create_chains

read_sdc $env(PROJ_ROOT)/constraints/sa_top_func_dft.sdc

# 6. Incremental optimisation + reports ---------------------------------------
syn_opt
check_dft_rules       > reports/dft_rules_post_connect.rpt
report_scan_chains    > reports/scan_chains.rpt
check_design -all     > reports/post_dft_check_design.rpt
check_timing_intent -verbose > reports/post_dft_timing_intent.rpt
report_area           > reports/post_dft_area.rpt
report_gates          > reports/post_dft_gates.rpt
report_timing -max_paths 10 > reports/post_dft_timing.rpt
report_qor            > reports/post_dft_qor.rpt
report_power          > reports/post_dft_power.rpt

# Sanity: no OAI32X1 instance may exist
set n_bad [llength [get_db insts -if {.base_cell.name == OAI32X1}]]
puts "OAI32X1_INSTANCES = $n_bad"

# 7. Outputs -------------------------------------------------------------------
write_hdl     > outputs/sa_top_syn_dft.v
write_sdc     > outputs/sa_top_syn_dft.sdc
write_scandef > outputs/sa_top_scanDEF.scandef
write_sdf -timescale ns -nonegchecks -recrem split -edges check_edge \
    -setuphold split > outputs/sa_top_dft_delays.sdf

# 8. Modus ATPG hand-off (creates test_scripts/)
write_dft_atpg -library $env(SIM_LIB_FUNC)

puts "SYNTHESIS_DFT_DONE"
