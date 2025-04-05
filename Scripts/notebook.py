import openlane
from openlane.config import Config
from openlane.steps import Step
from openlane.state import State

import os
import json
import re
import time
from metrics import InstanceDetails, TimingRptParser, StateOutMetrics

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
clock_period = 1.7
N = 4  # Number of iterations for the algorithm

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
UTILITY FUNCTIONS
'''
def print_available_steps():
    print(f"Openlane2 Version: {openlane.__version__}")
    print("Available Steps:")
    for step in Step.factory.list():
        print(step)


def file_finder(string, file_list):
    '''
    Given a string and a list of files, return the file that contains the string
    '''
    for file in file_list:
        with open(file, 'r') as f:
            if string in f.read():
                return file
    return None


def generate_pipeline_mask(startpoint: InstanceDetails, endpoint: InstanceDetails):
    """
    Generate pipeline mask based on the timing path between startpoint and endpoint.
    
    Args:
        startpoint: InstanceDetails object for the startpoint
        endpoint: InstanceDetails object for the endpoint
        
    Returns:
        Updated pipeline masks for both startpoint and endpoint instances
    """
    def shift_pipeline_bit(pipeline_mask, pipeline_stage, left):
        """
        Helper function to move the '1' bit from 'from_stage' to 'to_stage' in
        a pipeline mask string. Assumes leftmost bit = highest stage, rightmost bit = stage 0.
        Args:
            pipeline_mask: The pipeline mask string (e.g., "100110")
            pipeline_stage: The stage to move the '1' bit from (0-indexed)
            left: Boolean indicating the direction to move the bit.
                If True, move left (to a higher stage); if False, move right (to a lower stage).
        Returns:
            Updated pipeline mask string with the '1' bit moved
            and a boolean indicating if the operation was successful.
        """
        if pipeline_stage is None:
            return pipeline_mask, False

        bits = list(pipeline_mask)
        curr_idx = len(bits) - 1 - pipeline_stage

        if left:
            new_stage = pipeline_stage + 1
        else:
            new_stage = pipeline_stage - 1
            
        new_idx = len(bits) - 1 - new_stage

        # If either index is out of range, do nothing
        if not (0 <= curr_idx < len(bits)) or not (0 <= new_idx < len(bits)):
            return pipeline_mask, False
        # Move the '1' bit only if current bit is '1' and target bit is '0'
        if bits[curr_idx] == '1' and bits[new_idx] == '0':
            bits[curr_idx] = '0'
            bits[new_idx] = '1'
            return "".join(bits), True
        return pipeline_mask, False
    
    #  INPUT to REGISTER
    if startpoint.module == "INPUT":
        pipeline_mask, success = shift_pipeline_bit(endpoint.pipeline_mask, endpoint.pipeline_stage, left=False)
        if success:
            return None, None, pipeline_mask, endpoint.pipeline_stage - 1
        else:
            print("Warning: Unable to shift pipeline bit.")
            return None, None, endpoint.pipeline_mask, endpoint.pipeline_stage
    #  REGISTER to OUTPUT
    elif endpoint.module == "OUTPUT":
        pipeline_mask, success = shift_pipeline_bit(startpoint.pipeline_mask, startpoint.pipeline_stage, left=True)
        if success:
            return pipeline_mask, startpoint.pipeline_stage + 1, None, None
        else:
            print("Warning: Unable to shift pipeline bit.")
            return startpoint.pipeline_mask, startpoint.pipeline_stage, None, None
    #  REGISTER to REGISTER
    #  Known bug: might shift and override previous shifts.
    pipeline_mask, success = shift_pipeline_bit(startpoint.pipeline_mask, startpoint.pipeline_stage, left=True)
    if success:
        return pipeline_mask, startpoint.pipeline_stage + 1, endpoint.pipeline_mask, endpoint.pipeline_stage
    else:
        print("Warning: Unable to shift pipeline bit left. Trying to shift right.")
        pipeline_mask, success = shift_pipeline_bit(endpoint.pipeline_mask, endpoint.pipeline_stage, left=False)
        if success:
            return startpoint.pipeline_mask, startpoint.pipeline_stage, pipeline_mask, endpoint.pipeline_stage - 1
        else:
            print("Warning: Unable to shift pipeline bit.")
            return startpoint.pipeline_mask, startpoint.pipeline_stage, endpoint.pipeline_mask, endpoint.pipeline_stage
        

def modify_pipeline_mask(instance_id, custom_mask, file_path):
    """
    Modifies the PIPELINE_STAGE_MASK localparam in the given file.
    
    If a branch for (INSTANCE_ID == instance_id) exists in the mask, its mask
    is replaced with custom_mask. If it doesn't exist, a new branch is added 
    right after the equals sign.
    
    Example:
    For instance_id=1 and custom_mask="{ {STAGE_MASK_WIDTH-2{1'b0}}, 2'b11 }", 
    the line:
    
        localparam PIPELINE_STAGE_MASK = { {STAGE_MASK_WIDTH-NUM_PIPELINE_STAGES{1'b0}},
                                            {NUM_PIPELINE_STAGES{1'b1}} };
    
    will be transformed to:
    
        localparam PIPELINE_STAGE_MASK = (INSTANCE_ID == 1) ? { {STAGE_MASK_WIDTH-2{1'b0}}, 2'b11 } : { {STAGE_MASK_WIDTH-NUM_PIPELINE_STAGES{1'b0}},
                                            {NUM_PIPELINE_STAGES{1'b1}} };
    
    Parameters:
    instance_id (int or str): The instance id to update/insert.
    custom_mask (str): The custom mask string to use for the given instance.
    file_path (str): The path to the file containing the PIPELINE_STAGE_MASK line.
    """
    with open(file_path, 'r') as f:
        content = f.read()

    # Find the line that defines PIPELINE_STAGE_MASK.
    # We capture the part before the equals sign, the mask content, and the semicolon.
    pattern = r"(localparam\s+PIPELINE_STAGE_MASK\s*=\s*)(.*?)(\s*;)"
    match = re.search(pattern, content, re.DOTALL)
    if not match:
        print("PIPELINE_STAGE_MASK not found in file.")
        return

    prefix = match.group(1)          # e.g. "localparam PIPELINE_STAGE_MASK = "
    original_mask = match.group(2).strip()  # the current mask contents
    suffix = match.group(3)          # the semicolon and trailing spaces

    # Build a regex pattern for an existing branch for the given instance_id.
    branch_pattern = rf"\(INSTANCE_ID\s*==\s*{instance_id}\)\s*\?\s*([^:]+?)\s*:"

    if re.search(branch_pattern, original_mask):
        # Replace the existing branch's mask with the custom mask.
        new_branch = f"(INSTANCE_ID == {instance_id}) ? {len(custom_mask)}'b{custom_mask} :"
        new_mask = re.sub(branch_pattern, new_branch, original_mask, count=1)
    else:
        # Insert a new branch right after the equals sign.
        # Prepend the new branch before the current mask.
        new_branch = f"(INSTANCE_ID == {instance_id}) ? {len(custom_mask)}'b{custom_mask} : "
        new_mask = new_branch + original_mask

    # Reconstruct the full localparam line.
    new_line = prefix + new_mask + suffix

    # Replace the old definition in the file content.
    new_content = re.sub(pattern, new_line, content, count=1, flags=re.DOTALL)

    with open(file_path, 'w') as f:
        f.write(new_content)


def find_pipeline_stage(instance_name, module, top_module, iterations):
    '''
    Given an instance name and module, return the pipeline stage and pipeline mask.
    Args:
        instance_name: The name of the instance
        module: The module name
        top_module: The top module name
    Returns:
        num_pipelines: The number of pipeline stages
        pipeline_mask: The pipeline mask
        instance_id: The instance id
        num_enabled_pipeline_stages: The number of enabled pipeline stages
    '''
    with open(f"./openlane_run/{2*iterations+1}-yosys-synthesis/{top_module}.nl.v.json", 'r') as f:
        data = json.load(f)
    module_key = data["modules"][top_module]["cells"][instance_name]["type"]
    
    mask = f"{module}_pipeline_stage"
    module = data["modules"][module_key]["cells"]

    datawidth = int(data["modules"][module_key]["parameter_default_values"]["DATAWIDTH"], 2)
    num_pipelines = datawidth + 2
    instance_id = int(data["modules"][module_key]["parameter_default_values"]["INSTANCE_ID"], 2)
    num_enabled_pipeline_stages = int(data["modules"][module_key]["parameter_default_values"]["NUM_PIPELINE_STAGES"], 2)

    pipeline_details = {key : value for key, value in module.items() if mask in key}
    pipeline_mask = [0]*num_pipelines
    for key in pipeline_details.keys():
        if "ENABLE" in pipeline_details[key]["type"]:
            idx = num_pipelines - 1 - int(re.findall(r'\[(\d+)\]', key)[0])
            pipeline_mask[idx] = pipeline_details[key]["type"][-1]
    
    return num_pipelines, "".join(pipeline_mask), instance_id, num_enabled_pipeline_stages


def the_algorithm(condition, iterations):
    def remove_duplicates_keep_lowest_slack(data):
        best = {}
        for entry in data:
            sp = entry['startpoint']
            ep = entry['endpoint']
            slack = entry['slack']
            key = (sp, ep)

            current_best = best.get(key)
            if current_best is None or slack < current_best['slack']:
                best[key] = entry

        return list(best.values())

    # Get Data
    metrics = TimingRptParser(f"./openlane_run/{2*iterations+2}-openroad-staprepnr/{condition}/max.rpt") 
    instance_details = metrics.get_instance_details()
    
    simplified = remove_duplicates_keep_lowest_slack(instance_details)

    # Process Data
    for i, details in enumerate(simplified):
        if details["startpoint"].module != "INPUT":
            details["startpoint"].num_pipeline_stages, details["startpoint"].pipeline_mask, details["startpoint"].instance_id, details["startpoint"].num_enabled_pipeline_stages = find_pipeline_stage(details["startpoint"].instance_name, details["startpoint"].module, top_module[0], iterations)

        if details["endpoint"].module != "OUTPUT":
            details["endpoint"].num_pipeline_stages, details["endpoint"].pipeline_mask, details["endpoint"].instance_id, details["endpoint"].num_enabled_pipeline_stages = find_pipeline_stage(details["endpoint"].instance_name, details["endpoint"].module, top_module[0], iterations)
    
    violated_paths = [item for item in simplified if item["violated"]]
    violated_paths.sort(key=lambda x: x["slack"])  # Sorted by slack

    #print("ALL REGISTER")
    #for i in (simplified):
    #    print(i)
    print("VIOLATED REGISTER")
    for i in violated_paths:
        print(i)
    
    # Modify Files
    changed_modules = {}
    for data in violated_paths:
        if data["startpoint"].instance_id in changed_modules.keys() or data["endpoint"].instance_id in changed_modules.keys():
            continue
        else:
            module_file_location_startpoint = file_finder(data["startpoint"].module, design_paths + lib_paths)
            module_file_location_endpoint = file_finder(data["endpoint"].module, design_paths + lib_paths)
            print(f"Startpoint Module File Location: {module_file_location_startpoint}")
            print(f"Endpoint Module File Location: {module_file_location_endpoint}")
            print(f"Data: {data}")

            pm1, _, pm2, _ = generate_pipeline_mask(data["startpoint"], data["endpoint"])
            if pm1 != data["startpoint"].pipeline_mask:
                modify_pipeline_mask(data["startpoint"].instance_id, pm1, module_file_location_startpoint)
                changed_modules[data["startpoint"].instance_id] = data["startpoint"].pipeline_mask
            if pm2 != data["endpoint"].pipeline_mask:
                modify_pipeline_mask(data["endpoint"].instance_id, pm2, module_file_location_endpoint)
                changed_modules[data["endpoint"].instance_id] = data["endpoint"].pipeline_mask
    print(changed_modules)
    

for iterations in range(N):
    '''
    SYNTHESIS
    '''
    print_available_steps()

    Synthesis = Step.factory.get("Yosys.Synthesis")
    synthesis = Synthesis(
        VERILOG_FILES=FILES,
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
    stateout = StateOutMetrics(f"./openlane_run/{2*iterations+2}-openroad-staprepnr/state_out.json")
    if stateout.nom_ss_100C_1v60.metrics["timing__hold__ws"] < 0 or stateout.nom_ss_100C_1v60.metrics["timing__setup__ws"] < 0:
        print("Timing Violated For nom_ss_100C_1v60")
        the_algorithm("nom_ss_100C_1v60",  iterations)
    else:
        print("Timing Passed For nom_ss_100C_1v60")
        break
    time.sleep(3)
    '''
    # Disabled for now
    if stateout.nom_tt_025C_1v80.metrics["timing__hold__ws"] < 0 or stateout.nom_tt_025C_1v80.metrics["timing__setup__ws"] < 0:
        print("Timing Violated For nom_tt_025C_1v80")
        the_algorithm("nom_tt_025C_1v80",  iterations)
    else:
        print("Timing Passed For nom_tt_025C_1v80")

    if stateout.nom_ff_n40C_1v95.metrics["timing__hold__ws"] < 0 or stateout.nom_ff_n40C_1v95.metrics["timing__setup__ws"] < 0:
        print("Timing Violated For nom_ff_n40C_1v95")
        the_algorithm("nom_ff_n40C_1v95",  iterations)
    else:
        print("Timing Passed For nom_ff_n40C_1v95")
    '''
