#!/bin/bash
#=============================================================================
# run_rtl.sh - RTL simulation, self-checking testbench (Xcelium) + coverage
#   ./run_rtl.sh                     batch
#   ./run_rtl.sh -gui                SimVision
#   NTILES=50 SEED=7 ./run_rtl.sh
# Coverage DB: cov_work/scope/sa_selfcheck  ->  imc -load cov_work/scope/sa_selfcheck
#=============================================================================
source ../flow_config.sh
NTILES=${NTILES:-30}
SEED=${SEED:-1}

xrun -64bit -access +rwc -gui -timescale 1ns/1ps \
     -coverage all -covdut sa_top -covoverwrite -covtest sa_selfcheck \
     $PROJ_ROOT/rtl/sa_pe.v $PROJ_ROOT/rtl/sa_array.v $PROJ_ROOT/rtl/sa_top.v \
     $PROJ_ROOT/tb/tb_sa_top.v \
     -top tb_sa_top \
     +NTILES=$NTILES +SEED=$SEED \
     -l xrun_rtl.log "$@"

echo "------------------------------------------------------------"
grep -E "TEST (PASSED|FAILED)" xrun_rtl.log
