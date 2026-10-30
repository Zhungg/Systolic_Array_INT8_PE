#=============================================================================
# 01_init.tcl - import scan netlist, LEF, MMMC (same as ALU_32b import.tcl)
#=============================================================================
source [file join $::env(PROJ_ROOT) physical_design scripts common.tcl]

set_db init_power_nets  {VDD}
set_db init_ground_nets {VSS}

read_mmmc [file join $PD scripts mmmc.tcl]
read_physical -lef [list $::env(LEF_TECH) $::env(LEF_MACRO)]
read_netlist [file join $ROOT synthesis dft_run outputs sa_top_syn_dft_noassign.v] -top $DESIGN
init_design

# 45 nm process node (used by ALU_32b for extraction / route settings)
set_db design_process_node 45
apply_dont_use

# 72 port-to-port assigns of the Genus netlist were replaced by BUFX2 instances
# (scripts/remove_assigns.awk) so each c_out bit has its own net for LVS; keep them.
set_db [get_db insts FE_ASSIGN_BUF_*] .dont_touch true
puts "ASSIGN_BUFFERS = [llength [get_db insts FE_ASSIGN_BUF_*]]"

# Global PG connections (power.tcl of the lab, verified in ALU_32b)
connect_global_net VDD -type pg_pin -pin_base_name VDD -inst_base_name *
connect_global_net VSS -type pg_pin -pin_base_name VSS -inst_base_name *
connect_global_net VDD -type tie_hi
connect_global_net VSS -type tie_lo

# Quick statistics for the log
puts "INSTANCES = [llength [get_db insts]]"
puts "PORTS     = [llength [get_db ports]]"

write_db $DB(init)
puts "STAGE_01_INIT_DONE"
