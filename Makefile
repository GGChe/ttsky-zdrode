# Makefile: Verilog simulations + GTKWave with extra signals

IVERILOG_FLAGS := -g2005-sv
SIM_OUT        := sim.out
VCD            := wave.vcd

# Instead of a .gtkw savefile, use a Tcl script to add signals.
GTK_SAVE   :=
GTK_SCRIPT := tcl_scripts/signals.tcl
GTK_SCRIPT_PROCESSING_SYSTEM_FILE := tcl_scripts/signals_processing_system_file.tcl

.PHONY: all run_sim_processing_system run_sim_tt_project run_sim_tt_processing_system_io run_sim_ram clean

all: run_sim_processing_system run_sim_tt_project run_sim_tt_processing_system_io run_sim_ram


run_sim_processing_system:
	iverilog $(IVERILOG_FLAGS) -o $(SIM_OUT) src/*.v test/tb_processing_system_file.v
	vvp $(SIM_OUT)
	gtkwave -a $(GTK_SCRIPT_PROCESSING_SYSTEM_FILE) $(VCD) layout.sav


run_sim_tt_project:
	iverilog $(IVERILOG_FLAGS) -o $(SIM_OUT) \
	  src/processing_system.v src/ram.v src/processing_unit.v src/ado.v src/aso.v src/neo.v src/classifier.v  src/project.v \
	  test/tb_tt_module.v
	vvp $(SIM_OUT)
	gtkwave -a $(GTK_SCRIPT_PROCESSING_SYSTEM_FILE)  $(VCD) layout_project.sav


run_sim_tt_processing_system_io:
	iverilog $(IVERILOG_FLAGS) -o $(SIM_OUT) \
	  src/processing_system.v src/ram.v src/processing_unit.v src/aso.v src/classifier.v \
	  test/tb_processing_system_io.v
	vvp $(SIM_OUT)
	gtkwave -a $(GTK_SCRIPT) $(VCD) layout.sav

run_sim_ram:
	iverilog -o $(SIM_OUT) src/ram.v test/tb_ram16.v
	vvp $(SIM_OUT)
	gtkwave -a $(GTK_SCRIPT) $(VCD) layout.sav


plot:
	gtkwave -a $(GTK_SCRIPT_PROCESSING_SYSTEM_FILE) $(VCD) layout.sav


clean:
	rm -f $(SIM_OUT) wave.vcd *.vcd *.vvp *.vpi

