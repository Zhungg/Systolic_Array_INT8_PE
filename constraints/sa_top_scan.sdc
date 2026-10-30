#=============================================================================
# sa_top_scan.sdc - SCAN SHIFT mode, 20 MHz (stand-alone, Innovus/Tempus)
#
# SE = 1: the ~4.4k flops form 8 shift registers scan_in_i -> ... -> scan_out_i.
# Q -> SI paths are very short: setup is trivial, HOLD is the risk.
# Capture (SE = 0) at speed is covered by FUNC_MODE at 200 MHz.
#=============================================================================

create_clock -name clk -period 50.0 -waveform {0.0 25.0} [get_ports clk]
set_clock_transition 0.10 [get_clocks clk]
set_clock_uncertainty -setup 0.20 [get_clocks clk]
set_clock_uncertainty -hold  0.05 [get_clocks clk]

set_case_analysis 1 [get_ports SE]

set_input_delay  -max 5.0 -clock clk [get_ports {scan_in_* rst_n}]
set_input_delay  -min 0.5 -clock clk [get_ports {scan_in_* rst_n}]
set_driving_cell -lib_cell BUFX2 -pin Y [get_ports {scan_in_* rst_n SE}]

set_output_delay -max 5.0 -clock clk [get_ports {scan_out_*}]
set_output_delay -min 0.0 -clock clk [get_ports {scan_out_*}]
set_load 0.010 [get_ports {scan_out_* c_out[*] c_valid}]

# Functional data / control ports are meaningless while shifting
set_false_path -from [get_ports {a_in[*] a_valid a_bank w_in[*] w_load w_bank}]
set_false_path -to   [get_ports {c_out[*] c_valid}]
