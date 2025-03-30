import openlane
from openlane.config import Config
from openlane.steps import Step
from openlane.state import State
import os
from metrics import TimingRptParser
from dotenv import load_dotenv
load_dotenv(".env")


'''
CONFIGURATIONS
'''
### Make Changes here ###
cwd_path = os.getcwd()
## Design Modules
top_module = ["array_multiplier_top"]
design_modules = ["array_multiplier"]
design_paths = [f"{cwd_path}/../Design/Multiplier//{design_module}.sv" for design_module in design_modules+top_module]
## Library Modules
lib_modules = ["pipeline_stage"]
lib_paths = [f"{cwd_path}/../Design/lib/{lib_module}.sv" for lib_module in lib_modules]
## Clock pin name
clock_pin = "clk"
##Clock period
clock_period = 1

FILES = [path for path in design_paths + lib_paths if path]
Config.interactive(
    top_module[0],  # Assume first element of top_module list is the top module
    PDK="sky130A",
    PDK_ROOT=os.getenv("VOLARE_FOLDER"),  # create .env file with VOLARE_FOLDER=<path to skywater-pdk>
    CLOCK_PORT = clock_pin,
    CLOCK_NET = clock_pin,
    CLOCK_PERIOD = clock_period,
    PRIMARY_GDSII_STREAMOUT_TOOL="klayout",
)
## No changes bellow this line ###

'''
AVAILABLE STEPS
'''
def print_available_steps():
    print(f"Openlane2 Version: {openlane.__version__}")
    print("Available Steps:")
    for step in Step.factory.list():
        print(step)

print_available_steps()

'''
SYNTHESIS
'''
Synthesis = Step.factory.get("Yosys.Synthesis")
synthesis = Synthesis(
    VERILOG_FILES=FILES,
    state_in=State(),
)
synthesis.start()

# Static Timing Analysis Pre-PNR (STA Pre-PNR)
STAPrePNR = Step.factory.get("OpenROAD.STAPrePNR")
sta_pre_pnr = STAPrePNR(
    VERILOG_FILES=FILES,
    state_in=synthesis.state_out,  # Use the output state from synthesis as input state for STA Pre-PNR
)
sta_pre_pnr.start()

# Parse Timing Data.
metrics = TimingRptParser("./openlane_run/2-openroad-staprepnr/nom_ff_n40C_1v95/max_10_critical.rpt")  # nom_ff_n40C_1v95, nom_ss_100C_1v60, nom_tt_025C_1v80
instance_details = metrics.get_instance_details()


def file_finder(string, file_list):
    '''
    Given a string and a list of files, return the file that contains the string
    '''
    for file in file_list:
        with open(file, 'r') as f:
            if string in f.read():
                return file
    return None


print("Instance Details:")
for details in instance_details:
    print(details)
    if details.instance_name is not None:
        instance_file_location = file_finder(details.instance_name, design_paths + lib_paths)
        print(f"\t Instance File: {instance_file_location}")
    if details.module is not None:
        module_file_location = file_finder(f"{details.module}", design_paths + lib_paths)
        print(f"\t Module File: {module_file_location}")


