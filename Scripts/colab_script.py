import openlane
import glob
from openlane.config import Config
from openlane.steps import Step
from openlane.state import State
import openlane.logging

import os
import json
import re
import copy
import shutil
import subprocess
import random 
import argparse

from metrics import InstanceDetails, TimingRptParser, StateOutMetrics

# Added command-line argument parsing
parser = argparse.ArgumentParser(description='Run the pipeline adjustment algorithm with optional clock period increase.')
parser.add_argument('--increase-clock', action='store_true', help='Allow automatic clock period increase when timing violations occur.')
parser.add_argument('--clock-period', type=float, default=20.0, help='Initial clock period to use in the design (in ns).')
parser.add_argument('--Iterations', type=int, default=50, help='Max Iteration count for the algorithm')
parser.add_argument('--naive-config', action='store_true', help='naive configuration to check the clock which design satisfies without any modification')
args = parser.parse_args()

openlane.logging.set_log_level("CRITICAL")

'''
CONFIGURATIONS
'''
### Make Changes here ###
cwd_path = os.getcwd()
## Design Modules

'''
top_module = ["top"]
design_paths = [f"{cwd_path}/../Design/Multiplier/array_multiplier.sv",
                 f"{cwd_path}/../Design/Divider/divider.sv",
                 f"{cwd_path}/../Design/AdderTree/AdderTree.sv",
                 f"{cwd_path}/../Design/SquareRoot/squareroot.sv",
                 f"{cwd_path}/../Design/Top/top.sv"] 
'''
top_module = ["top_mult_addertree"]
design_paths = [f"{cwd_path}/../Design/Multiplier/array_multiplier.sv", 
                f"{cwd_path}/../Design/AdderTree/AdderTree.sv",
                f"{cwd_path}/../Design/Top_mult_addertree/top_mult_addertree.sv"]

## Library Modules
lib_modules = ["pipeline_stage"]
lib_paths = [f"{cwd_path}/../Design/lib/{lib_module}.sv" for lib_module in lib_modules]
## Clock pin name
clock_pin = "clk"
## Clock period
clock_period = args.clock_period  # Working Clock Period
## Number of iterations for the algorithm
N_iterations = args.Iterations  # Number of iterations for the algorithm

FILES = [path for path in design_paths + lib_paths if path]
## No changes bellow this line ###

with open('metrics/utils.py') as f:
    exec(f.read())

'''
SYNTHESIS
'''
flag_stop = False
telemetry = {"attempted_pipeline_combinations":set(), "kill_count":0, "kill":False, "iterations":0}
backup_files = create_backup_files(design_paths)
while not flag_stop:
    for iterations in range(N_iterations):
        # print_available_steps()

        # Dumping raw netlist
        verilog_str = " ".join(FILES)
        yosys_cmd = f'rm -rf ./openlane_run/*yosys* ./openlane_run/*openroad*; mkdir -p ./openlane_run; yosys -Q -qq -p "read_verilog -sv {verilog_str}; hierarchy -top {top_module[0]}; proc; write_json ./openlane_run/raw_netlist.json"'
        # Run Yosys comman
        subprocess.run(yosys_cmd, shell=True, check=True)

        Config.interactive(
            top_module[0],  # Assume first element of top_module list is the top module
            PDK="sky130A",
            PDK_ROOT=os.getenv("VOLARE_FOLDER"),  # create .env file with VOLARE_FOLDER=<path to skywater-pdk>
            CLOCK_PORT = clock_pin,
            CLOCK_NET = clock_pin,
            CLOCK_PERIOD = clock_period,
            PRIMARY_GDSII_STREAMOUT_TOOL="klayout",
        )

        Synthesis = Step.factory.get("Yosys.Synthesis")
        synthesis = Synthesis(
            VERILOG_FILES=FILES,
            SYNTH_NO_FLAT=True,
            YOSYS_LOG_LEVEL="ERROR",
            SYNTH_STRATEGY="DELAY 1", 
            SYNTH_ABC_BUFFERING=True,            # Enable cell buffering
            state_in=State(),
        )
        synthesis.start()

        # Static Timing Analysis Pre-PNR (STA Pre-PNR)
        STAPrePNR = Step.factory.get("OpenROAD.STAPrePNR")
        sta_pre_pnr = STAPrePNR(
            PNR_SDC_FILE="pre_pnr_base.sdc",
            VERILOG_FILES=FILES,
            state_in=synthesis.state_out,  # Use the output state from synthesis as input state for STA Pre-PNR
        )
        sta_pre_pnr.start()

        # Parse Timing Data.
        it = telemetry["iterations"]
        print("============================================================")
        print(f"Iteration {it}")
        print("============================================================")
        openroad_state_path = glob.glob("./openlane_run/*-openroad-*/state_out.json")[0]
        stateout = StateOutMetrics(openroad_state_path)
        if stateout.nom_ss_100C_1v60.metrics["timing__hold__ws"] < 0 or stateout.nom_ss_100C_1v60.metrics["timing__setup__ws"] < 0:
            print("Timing Violated For nom_ss_100C_1v60")
            if not args.naive_config:
                temp_telemetry = the_algorithm("nom_ss_100C_1v60",  telemetry)
                if temp_telemetry["kill"]:
                    print("Kill Condition Met")
                    #print(temp_telemetry)
                    break
                telemetry = temp_telemetry
        else:
            print(f"Timing Passed For nom_ss_100C_1v60 for clock period of {clock_period}")
            temp_telemetry = the_algorithm("nom_ss_100C_1v60",  telemetry)
            flag_stop = True
            break
        # print("============================================================")
        # print("One Iteration Completed")
        # print("============================================================")
        #input()
    
    if not flag_stop:
        if args.increase_clock:
            # Proceed with increasing clock period
            if not args.naive_config:
                telemetry = temp_telemetry
            telemetry["attempted_pipeline_combinations"].clear()
            telemetry["kill_count"] = 0
            telemetry["kill"] = False
            clock_period = round(clock_period + 0.1, 2)
            print("============================================================")
            print(f"Increasing clock period to {clock_period}")
            print("============================================================")
            # input("Press Enter To Continue With Increased Clock Period...")
        else:
            # Print message and exit if the argument is not provided
            print("============================================================")
            print(f"Make the design choice of either increasing the number of pipeline stages or increasing the current clock period {clock_period}.")
            print("============================================================")
            break

