#You should be in the "sim/" directory

INCLUDE_FILE_NAME=top_tb.include

#Defines statement for vcs
VERILOG_DEFINES:=+SIM=1

.DEFAULT_GOAL := run_and_view
CURRENT_DIR := $(shell pwd)
WORKSPACE = $(CURRENT_DIR)/WORKSPACE
TESTNAME :=


help:
	@echo "----------------------------------------------------------------"
	@echo "Administrative targets:"
	@echo "  help           - lists make options"
	@echo "  clean          - removes the temporary files created by sim"
	@echo
	@echo "Compilation targets:"
	@echo "  link          - creates symbolic links between src and sim"
	@echo "                 folders for files listed in <design>.include"
	@echo "  vcs           - compiles code and runs simulation using vcs."
	@echo "                  make sure to run make link first"
	@echo
	@echo "Viewing targets:"
	@echo "  dve           - runs DVE to view waveforms from simulation"
	@echo "  run_and_view  - combo of make vcs and make dve"
	@echo "  verdi         - runs Verdi to view waveforms from simulation"
	@echo "  coverage      - runs Verdi to view coverage report"
	@echo 
	@echo "----------------------------------------------------------------"

link:
	if [ ! -d "$(WORKSPACE)" ]; then \
		mkdir $(WORKSPACE); \
	else \
		cd $(WORKSPACE); \
	fi
	rm -f $(WORKSPACE)/sym_links/*.sv*
	python3.12 link_files.py ${INCLUDE_FILE_NAME}

run_and_view:
	make vcs
	make dve

dve:
	cd $(WORKSPACE) && \
	dve -full64 -vpd simulation.vpd&

verdi:
	cd $(WORKSPACE) && \
	verdi -sv -simBin ./simv \
	      -dbdir ./simv.daidir \
    	  -ssf ./simulation.fsdb &

coverage:
	cd $(WORKSPACE) && \
	verdi -cov -covdir simv.vdb&

vcs: ./Include/${INCLUDE_FILE_NAME}
	cd $(WORKSPACE) && \
	vcs -file sym_links/sim_no_path.include +v2k -R +lint=all -sverilog -full64 -kdb \
		-timescale=1ns/10ps -debug_acc+pp+dmptf -debug_region+cell+encrypt \
		-cm line+tgl+cond+branch+fsm+assert -debug_access+all -l simulation.log +vpdfile+./simulation.vpd +fsdb+./simulation.fsdb +dumpvars +define+$(VERILOG_DEFINES) +testname=$(TESTNAME) \
		+incdir+sym_links
		# simv

clean:
	rm -rf WORKSPACE

