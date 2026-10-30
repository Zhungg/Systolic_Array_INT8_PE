#=============================================================================
# sa_top_func.sdc - FUNCTIONAL mode, 200 MHz
# Used by : Genus (only file read before scan ports exist)
#           Innovus / Tempus FUNC_MODE  (+ sa_top_func_dft.sdc)
# Units   : ns, pF   (gsclib045 liberty)
#
# Same structure as the ALU_32b project, period 10 ns -> 5 ns.
# Every port is registered inside sa_top, so I/O budgets can be generous:
#   input  : 20 % of the period used outside (1.0 ns)
#   output : 20 % of the period needed outside (1.0 ns)
#=============================================================================

create_clock -name clk -period 5.0 -waveform {0.0 2.5} [get_ports clk]

set_clock_transition 0.10 [get_clocks clk]
set_clock_uncertainty -setup 0.15 [get_clocks clk]
set_clock_uncertainty -hold  0.05 [get_clocks clk]

#---------------- inputs ------------------------------------------------------
set_input_delay -max 1.0 -clock clk [get_ports {a_in[*] a_valid a_bank w_in[*] w_load w_bank rst_n}]
set_input_delay -min 0.5 -clock clk [get_ports {a_in[*] a_valid a_bank w_in[*] w_load w_bank rst_n}]
set_driving_cell -lib_cell BUFX2 -pin Y [get_ports {a_in[*] a_valid a_bank w_in[*] w_load w_bank rst_n}]

#---------------- outputs -----------------------------------------------------
set_output_delay -max 1.0 -clock clk [get_ports {c_out[*] c_valid}]
set_output_delay -min 0.0 -clock clk [get_ports {c_out[*] c_valid}]
set_load 0.010 [get_ports {c_out[*] c_valid}]
