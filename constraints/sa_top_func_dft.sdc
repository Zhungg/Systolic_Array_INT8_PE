#=============================================================================
# sa_top_func_dft.sdc - add-on for FUNC_MODE after scan insertion (8 chains)
# Read after the scan ports exist (Genus after connect_scan_chains, Innovus).
#=============================================================================

set_case_analysis 0 [get_ports SE]

set_input_delay  -max 1.0 -clock clk [get_ports {SE scan_in_*}]
set_input_delay  -min 0.5 -clock clk [get_ports {SE scan_in_*}]
set_driving_cell -lib_cell BUFX2 -pin Y [get_ports {SE scan_in_*}]

set_output_delay -max 1.0 -clock clk [get_ports {scan_out_*}]
set_output_delay -min 0.0 -clock clk [get_ports {scan_out_*}]
set_load 0.010 [get_ports {scan_out_*}]
