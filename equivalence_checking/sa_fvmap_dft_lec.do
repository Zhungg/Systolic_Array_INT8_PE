//============================================================================
// sa_dft_lec.do - RTL (golden) vs scan-inserted netlist (revised)
// Same method as ALU_32b; 8 scan chains.  Run via run_lec.sh
//============================================================================
set log file reports/sa_fvmap_dft_lec.log -replace

read library @SIM_LIB_FUNC@ -verilog -both

read design ../synthesis/dft_run/fv/sa_top/fv_map.v.gz -verilog -golden

read design ../synthesis/dft_run/outputs/sa_top_syn_dft.v -verilog -revised

// functional mode: shift disabled, scan I/O not part of the function
add pin constraints 0 SE -revised
add ignored inputs  scan_in_0 scan_in_1 scan_in_2 scan_in_3 scan_in_4 scan_in_5 scan_in_6 scan_in_7 -revised
add ignored outputs scan_out_0 scan_out_1 scan_out_2 scan_out_3 scan_out_4 scan_out_5 scan_out_6 scan_out_7 -revised

set system mode lec

add compared points -all
compare

report verification
report statistics

exit
