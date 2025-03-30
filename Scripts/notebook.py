import openlane
from openlane.config import Config
from openlane.steps import Step
from openlane.state import State
import os
import json
from metrics import TimingRptParser, StateOutMetrics
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


def update_pipeline_mask(instance_id, new_mask, file_path):
    """
    Updates (or adds) an instance case in the get_pipeline_mask function in the given file.

    If a case for the given instance_id exists, its pipeline mask is updated.
    Otherwise, a new case is inserted before the default case.

    Parameters:
      instance_id (int): The instance id to update or add.
      new_mask (str): The pipeline mask assignment as a string
                      (e.g., "{ {STAGE_MASK_WIDTH-NUM_PIPELINE_STAGES{1'b0}}, {NUM_PIPELINE_STAGES{1'b1}} }").
      file_path (str): The path to the Verilog file.
    """
    with open(file_path, 'r') as f:
        lines = f.readlines()

    # Locate the get_pipeline_mask function block.
    func_start = None
    func_end = None
    for i, line in enumerate(lines):
        if "function automatic" in line and "get_pipeline_mask" in line:
            func_start = i
            break
    if func_start is None:
        raise Exception("get_pipeline_mask function not found.")

    for i in range(func_start, len(lines)):
        if "endfunction" in lines[i]:
            func_end = i
            break
    if func_end is None:
        raise Exception("endfunction not found for get_pipeline_mask.")

    # Locate the case statement and the default line within the function block.
    case_start = None
    default_index = None
    for i in range(func_start, func_end):
        if "case" in lines[i] and "instance_id" in lines[i]:
            case_start = i
        if "default:" in lines[i]:
            default_index = i
            break
    if case_start is None:
        raise Exception("case (instance_id) not found in the function block.")
    if default_index is None:
        raise Exception("default: case not found in the function block.")

    # Search for an existing instance case between the case statement and default.
    instance_index = None
    for i in range(case_start, default_index):
        stripped = lines[i].strip()
        # Check if line starts with the instance id followed by a colon.
        if stripped.startswith(f"{instance_id}:"):
            instance_index = i
            break

    # Prepare the new case line using the indent of the default line.
    default_line = lines[default_index]
    indent = default_line[:len(default_line) - len(default_line.lstrip())]
    new_case_line = f"{indent}{instance_id}: get_pipeline_mask = {new_mask}; // THIS LINE WAS ADDED BY THE SCRIPT\n"

    if instance_index is not None:
        # Overwrite the existing line.
        lines[instance_index] = new_case_line
    else:
        # Insert the new case line just before the default case.
        lines.insert(default_index, new_case_line)

    with open(file_path, 'w') as f:
        f.writelines(lines)


def find_pipeline_stage(instance_name, module, top_module):
    with open(f"./openlane_run/1-yosys-synthesis/{top_module}.nl.v.json", 'r') as f:
        data = json.load(f)
    module_key = data["modules"][top_module]["cells"][instance_name]["type"]
    
    mask = f"{module}_pipeline_stage"
    module = data["modules"][module_key]["cells"]

    datawidth = int(data["modules"][module_key]["parameter_default_values"]["DATAWIDTH"], 2)
    num_pipelines = datawidth + 2
    instance_id = int(data["modules"][module_key]["parameter_default_values"]["INSTANCE_ID"], 2)
    num_enabled_pipeline_stages = int(data["modules"][module_key]["parameter_default_values"]["NUM_PIPELINE_STAGES"], 2)

    pipeline_details = {key : value for key, value in module.items() if mask in key}
    pipeline_mask = ""
    for key in pipeline_details.keys():
        if "ENABLE" in pipeline_details[key]["type"]:
            pipeline_mask = pipeline_details[key]["type"][-1]+pipeline_mask

    return num_pipelines, pipeline_mask, instance_id, num_enabled_pipeline_stages


def get_register_metrics(condition):
    metrics = TimingRptParser(f"./openlane_run/2-openroad-staprepnr/{condition}/max_10_critical.rpt") 
    instance_details = metrics.get_instance_details()

    print("Instance Details:")
    for i, details in enumerate(instance_details):
        module_file_location = ""

        if details["startpoint"].module != "INPUT":
            details["startpoint"].num_pipeline_stages, details["startpoint"].pipeline_mask, details["startpoint"].instance_id, details["startpoint"].num_enabled_pipeline_stages = find_pipeline_stage(details["startpoint"].instance_name, details["startpoint"].module, top_module[0])

        if details["endpoint"].module != "OUTPUT":
            details["endpoint"].num_pipeline_stages, details["endpoint"].pipeline_mask, details["endpoint"].instance_id, details["endpoint"].num_enabled_pipeline_stages = find_pipeline_stage(details["endpoint"].instance_name, details["endpoint"].module, top_module[0])
        # print(details)
    # print()
    simplified = {}
    for item in instance_details:
        key = (item["startpoint"].module, item["endpoint"].module)
        if key not in simplified:
            simplified[key] = item.copy()
        else:
            simplified[key]["slack"] = min(simplified[key]["slack"], item["slack"])
            simplified[key]["violated"] = simplified[key]["violated"] or item["violated"]
    simplified_data = list(simplified.values())

    for data in simplified_data:
        module_file_location = file_finder(data["startpoint"].module, design_paths + lib_paths)
        print(f"Module File: {module_file_location}")
        print(f"Data: {data}")
        # Add or Update pipeline mask in module file. Current code just duplicates what it founds in the module file and writes it explicity to the case.
        if data["startpoint"].module != "INPUT":
            print(f"Updating {data['startpoint'].instance_id} with {data['startpoint'].pipeline_mask}")
            update_pipeline_mask(data["startpoint"].instance_id, data["startpoint"].pipeline_mask, module_file_location)
        if data["endpoint"].module != "OUTPUT":
            print(f"Updating {data['endpoint'].instance_id} with {data['endpoint'].pipeline_mask}")
            update_pipeline_mask(data["endpoint"].instance_id, data["endpoint"].pipeline_mask, module_file_location)
        print()


# Parse Timing Data.
stateout = StateOutMetrics("./openlane_run/2-openroad-staprepnr/state_out.json")
if stateout.nom_ss_100C_1v60.metrics["timing__hold__ws"] < 0 or stateout.nom_ss_100C_1v60.metrics["timing__setup__ws"] < 0:
    print("Timing Violated For nom_ss_100C_1v60")
    get_register_metrics("nom_ss_100C_1v60")
else:
    print("Timing Passed For nom_ss_100C_1v60")
'''
# Disabled for now
if stateout.nom_tt_025C_1v80.metrics["timing__hold__ws"] < 0 or stateout.nom_tt_025C_1v80.metrics["timing__setup__ws"] < 0:
    print("Timing Violated For nom_tt_025C_1v80")
    get_register_metrics("nom_tt_025C_1v80")
else:
    print("Timing Passed For nom_tt_025C_1v80")

if stateout.nom_ff_n40C_1v95.metrics["timing__hold__ws"] < 0 or stateout.nom_ff_n40C_1v95.metrics["timing__setup__ws"] < 0:
    print("Timing Violated For nom_ff_n40C_1v95")
    get_register_metrics("nom_ff_n40C_1v95")
else:
    print("Timing Passed For nom_ff_n40C_1v95")
'''