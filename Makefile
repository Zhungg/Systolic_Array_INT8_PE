# Open-source quick check (no Cadence licenses needed).
#   make sim [NTILES=30] [SEED=1]   compile + run the self-checking testbench
#   make lint                         Verilator lint of the RTL
#   make clean
# The sign-off flow itself uses the Cadence scripts described in README.md.

NTILES ?= 30
SEED  ?= 1
RTL   := rtl/sa_pe.v rtl/sa_array.v rtl/sa_top.v
TB    := tb/tb_sa_top.v
BUILD := build

.PHONY: sim lint clean

sim: $(BUILD)/tb_sa_top.vvp
	vvp $< +NTILES=$(NTILES) +SEED=$(SEED) | tee $(BUILD)/sim.log
	@grep -q "\*\*\* TEST PASSED \*\*\*" $(BUILD)/sim.log

$(BUILD)/tb_sa_top.vvp: $(RTL) $(TB)
	@mkdir -p $(BUILD)
	iverilog -g2012 -Wall -s tb_sa_top -o $@ $(RTL) $(TB)

lint:
	verilator --lint-only --top-module sa_top -Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL $(RTL)

clean:
	rm -rf $(BUILD)
