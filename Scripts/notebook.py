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


def file_finder(string, file_list):
    '''
    Given a string and a list of files, return the file that contains the string
    '''
    for file in file_list:
        with open(file, 'r') as f:
            if string in f.read():
                return file
    return None


def find_pipeline_stage(module, top_module):
    '''
    Returns how many pipeline stages are there in the module
    '''
    with open(f"./openlane_run/1-yosys-synthesis/{top_module}.nl.v.json", 'r') as f:
        data = f.read().split('\n')
    mask = f"{module}_pipeline_stage"
    # Find the line that contains string in the file add line to python set
    lines = set()
    for i, line in enumerate(data):
        if mask in line:
            pipeline_stage = line[line.find(module):line.find("]")+1]
            lines.add(pipeline_stage)

    counter = 0
    pipeline_mask = ""
    for i, line in enumerate(data):
        if counter == len(lines):
            break
        if "ENABLE" in line:
            counter += 1
            pipeline_mask = line[-3]+pipeline_mask

    return len(lines), pipeline_mask

    
# Parse Timing Data.
# TODO: Read StateOutMetrics and see if there are any timing violations. If there are, then we parse timing report for that corner/group.
metrics = TimingRptParser("./openlane_run/2-openroad-staprepnr/nom_ff_n40C_1v95/max_10_critical.rpt")  # nom_ff_n40C_1v95, nom_ss_100C_1v60, nom_tt_025C_1v80
instance_details = metrics.get_instance_details()
print(metrics.get_paths())

print("Instance Details:")
for i, details in enumerate(instance_details):
    module_file_location = ""
    num_pipeline_stages = None
    pipeline_mask = None

    if details["startpoint"].module != "INPUT":
        num_pipeline_stages, pipeline_mask = find_pipeline_stage(details["startpoint"].module, top_module[0])
    instance_details[i]["num_pipeline_stages"] = num_pipeline_stages
    instance_details[i]["pipeline_mask"] = pipeline_mask

    print(details)
    print()

simplified = {}
for item in instance_details:
    key = (item["startpoint"].module, item["endpoint"].module)
    if key not in simplified:
        simplified[key] = item.copy()
    else:
        simplified[key]["slack"] = min(simplified[key]["slack"], item["slack"])
        simplified[key]["violated"] = simplified[key]["violated"] or item["violated"]

simplified_data = list(simplified.values())

for i in simplified_data:
    print(i)


'''
# Only if not INPUT
module_file_location = file_finder(details["startpoint"].module, design_paths + lib_paths)
print(f"Module File: {module_file_location}\n")'
'''