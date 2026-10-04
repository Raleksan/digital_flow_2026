# ============================================================
# Environment
# ============================================================

# bash + pipefail: a failed compile is not hidden by "| tee"
SHELL       := /bin/bash
.SHELLFLAGS := -o pipefail -c

export ENV_DESIGN_DIR = $(PWD)/data

RTL_DIR = $(ENV_DESIGN_DIR)/rtl

XRUN      = xrun
VERILATOR = verilator


# ============================================================
# Sources
# ============================================================

# RTL sources of each block. Blocks that use other blocks list
# their sources too (see RTL_PROCESSING_SYSTEM).

RTL_COUNTER = \
	$(RTL_DIR)/counter/counter.sv

RTL_STATISTICS_UNIT = \
	$(RTL_DIR)/statistics_unit/statistics_unit.sv

RTL_PROCESSING_UNIT = \
	$(RTL_DIR)/processing_unit/processing_pkg.sv \
	$(RTL_DIR)/processing_unit/processing_unit.sv

# TODO: processing_system
# RTL_PROCESSING_SYSTEM = \
# 	$(RTL_PROCESSING_UNIT) \
# 	$(RTL_STATISTICS_UNIT) \
# 	$(RTL_DIR)/processing_system/processing_system.sv

# Files of each testbench: SIM_FILES_<testbench top>

SIM_FILES_counter_tb = \
	$(RTL_COUNTER) \
	$(RTL_DIR)/counter/counter_tb.sv

SIM_FILES_statistics_unit_tb = \
	$(RTL_STATISTICS_UNIT) \
	$(RTL_DIR)/statistics_unit/tb/statistics_unit_tb.sv

# TODO: processing_system_tb
# SIM_FILES_processing_system_tb = \
# 	$(RTL_PROCESSING_SYSTEM) \
# 	$(RTL_DIR)/processing_system/tb/processing_system_tb.sv


# ============================================================
# Simulation settings
# ============================================================

# Testbench to run: make sim_verilator SIM_TOP=counter_tb
SIM_TOP ?= statistics_unit_tb

# Extra files from the command line: make sim EXTRA_FILES=...
EXTRA_FILES ?=

SIM_FILES = $(SIM_FILES_$(SIM_TOP)) $(abspath $(EXTRA_FILES))

ifeq ($(strip $(SIM_FILES_$(SIM_TOP))),)
$(error No file list for SIM_TOP=$(SIM_TOP). Define SIM_FILES_$(SIM_TOP) in Makefile)
endif

# All build and run artifacts go here (gitignored)
BUILD_DIR = $(PWD)/build

XRUN_RUN_DIR      = $(BUILD_DIR)/xrun/$(SIM_TOP)
VERILATOR_RUN_DIR = $(BUILD_DIR)/verilator/$(SIM_TOP)

XRUN_OPTS = \
	-access +rw \
	-clean \
	-seed random \
	-timescale 1ns/1ps

VERILATOR_OPTS = \
	--binary \
	--timing \
	--assert \
	--trace \
	--timescale 1ns/1ps \
	-Wno-fatal \
	-Wno-lint \
	-Wno-style


# ============================================================
# Targets
# ============================================================

all: sim


# ----------------------------------------
# Help
# ----------------------------------------

# Testbenches that have a SIM_FILES_<top> list
SIM_TOPS = $(sort $(patsubst SIM_FILES_%,%,$(filter SIM_FILES_%,$(.VARIABLES))))

help:
	@echo "Usage: make <target> [SIM_TOP=<testbench>] [EXTRA_FILES=\"<files>\"]"
	@echo ""
	@echo "Targets:"
	@echo "  sim            Xcelium simulation with GUI (default)"
	@echo "  sim_nogui      Xcelium simulation without GUI"
	@echo "  sim_verilator  Verilator build and simulation"
	@echo "  clean          Remove $(BUILD_DIR)"
	@echo "  help           Show this message"
	@echo ""
	@echo "Variables:"
	@echo "  SIM_TOP        Testbench top (current: $(SIM_TOP))"
	@echo "  EXTRA_FILES    Additional source files to compile"
	@echo ""
	@echo "Available testbenches:"
	@$(foreach t,$(SIM_TOPS),echo "  $(t)";)
	@echo ""
	@echo "Results: $(BUILD_DIR)/<tool>/<SIM_TOP>/"
	@echo ""
	@echo "Examples:"
	@echo "  make sim_verilator"
	@echo "  make sim_nogui SIM_TOP=counter_tb"


# ----------------------------------------
# Simulation
# ----------------------------------------

$(XRUN_RUN_DIR) $(VERILATOR_RUN_DIR):
	mkdir -p $@

# Simulation with GUI
sim: $(XRUN_RUN_DIR)
	@echo "=== Starting Simulation (GUI) ==="
	@echo "Top: $(SIM_TOP)"
	@echo "Files: $(SIM_FILES)"
	cd $(XRUN_RUN_DIR) && \
		$(XRUN) $(XRUN_OPTS) \
		$(SIM_FILES) \
		-top $(SIM_TOP) \
		-gui \
		2>&1 | tee sim.log
	@echo "=== Simulation Complete ==="
	@echo "Results in: $(XRUN_RUN_DIR)"


# Simulation without GUI
sim_nogui: $(XRUN_RUN_DIR)
	@echo "=== Starting Simulation (No GUI) ==="
	@echo "Top: $(SIM_TOP)"
	@echo "Files: $(SIM_FILES)"
	cd $(XRUN_RUN_DIR) && \
		$(XRUN) $(XRUN_OPTS) \
		$(SIM_FILES) \
		-top $(SIM_TOP) \
		2>&1 | tee sim.log
	@echo "=== Simulation Complete ==="
	@echo "Results in: $(XRUN_RUN_DIR)"


# Simulation with Verilator (without Xcelium)
sim_verilator: $(VERILATOR_RUN_DIR)
	@echo "=== Starting Simulation (Verilator) ==="
	@echo "Top: $(SIM_TOP)"
	@echo "Files: $(SIM_FILES)"
	cd $(VERILATOR_RUN_DIR) && \
		$(VERILATOR) $(VERILATOR_OPTS) \
		$(SIM_FILES) \
		--top-module $(SIM_TOP) \
		2>&1 | tee build.log && \
		./obj_dir/V$(SIM_TOP) 2>&1 | tee sim.log
	@echo "=== Simulation Complete ==="
	@echo "Results in: $(VERILATOR_RUN_DIR)"


# ----------------------------------------
# Clean
# ----------------------------------------

clean:
	rm -rf $(BUILD_DIR)


.PHONY: all help sim sim_nogui sim_verilator clean
