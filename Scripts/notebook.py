import openlane
from openlane.config import Config
from openlane.steps import Step
from openlane.state import State

import os
import json
import re
import copy
import shutil
import subprocess
import random 

from metrics import InstanceDetails, TimingRptParser, StateOutMetrics

from dotenv import load_dotenv
load_dotenv(".env")


'''
CONFIGURATIONS
'''
### Make Changes here ###
cwd_path = os.getcwd()
## Design Modules

top_module = ["top"]
design_paths = [f"{cwd_path}/../Design/Multiplier/array_multiplier.sv",
                 f"{cwd_path}/../Design/Divider/divider.sv",
                 f"{cwd_path}/../Design/AdderTree/AdderTree.sv",
                 f"{cwd_path}/../Design/SquareRoot/squareroot.sv",
                 f"{cwd_path}/../Design/Top/top.sv"] 
'''
top_module = ["sqrt_int"]
design_paths = [f"{cwd_path}/../Design/SquareRoot/squareroot.sv"]
'''
## Library Modules
lib_modules = ["pipeline_stage"]
lib_paths = [f"{cwd_path}/../Design/lib/{lib_module}.sv" for lib_module in lib_modules]
## Clock pin name
clock_pin = "clk"
## Clock period
clock_period = 2.0
## Number of iterations for the algorithm
N_iterations = 10

FILES = [path for path in design_paths + lib_paths if path]
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


def create_backup_files(file_paths):
    """
    Given a list of file paths, create a copy of each file in the same directory 
    with the filename suffixed by '_backup'.
    """
    backup_file_paths = []
    for original_path in file_paths:
        directory, filename = os.path.split(original_path)
        name, extension = os.path.splitext(filename)
        backup_filename = f"{name}_backup{extension}"
        backup_path = os.path.join(directory, backup_filename)
        shutil.copy2(original_path, backup_path)
        backup_file_paths.append(backup_path)

    return backup_file_paths


def restore_backup_files(backup_file_paths):
    """
    Given a list of backup file paths (e.g., 'example_backup.txt'), 
    copy each backup file back to its original name (e.g., 'example.txt'),
    overwriting the original if it exists.
    """
    for backup_path in backup_file_paths:
        directory, filename = os.path.split(backup_path)
        name, extension = os.path.splitext(filename)
        if name.endswith('_backup'):
            original_name = name[:-7]  # remove '_backup' from the filename
            original_filename = original_name + extension
            original_path = os.path.join(directory, original_filename)
            shutil.copy2(backup_path, original_path)
            os.remove(backup_path)


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


def generate_pipeline_mask(startpoint: InstanceDetails, endpoint: InstanceDetails, pipeline_details: list, telemetry: dict):
    """
    Generate pipeline mask based on the timing path between startpoint and endpoint.
    
    Args:
        startpoint: InstanceDetails object for the startpoint
        endpoint: InstanceDetails object for the endpoint
        pipeline_details: List of pipeline details contatining all startpoint and endpoints
    Returns:
        Updated pipeline masks for both startpoint and endpoint instances
    """
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
    if telemetry["kill_count"] > 0:
        random_bit = random.randint(0, 1)
        if random_bit == 0:
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
        else:
            pipeline_mask, success = shift_pipeline_bit(endpoint.pipeline_mask, endpoint.pipeline_stage, left=False)
            if success:
                return startpoint.pipeline_mask, startpoint.pipeline_stage, pipeline_mask, endpoint.pipeline_stage - 1
            else:
                print("Warning: Unable to shift pipeline bit right. Trying to shift left.")
                pipeline_mask, success = shift_pipeline_bit(startpoint.pipeline_mask, startpoint.pipeline_stage, left=True)
                if success:
                    return pipeline_mask, startpoint.pipeline_stage + 1, endpoint.pipeline_mask, endpoint.pipeline_stage
                else:
                    print("Warning: Unable to shift pipeline bit.")
                    return startpoint.pipeline_mask, startpoint.pipeline_stage, endpoint.pipeline_mask, endpoint.pipeline_stage
    else:
        startpoint_as_endpoint = None
        endpoint_as_startpoint = None
        for pipeline in pipeline_details:
            if startpoint == pipeline["endpoint"]:
                startpoint_as_endpoint = pipeline
            if endpoint == pipeline["startpoint"]:
                endpoint_as_startpoint = pipeline
            if startpoint_as_endpoint != None and endpoint_as_startpoint != None:  
                break

        if startpoint_as_endpoint["slack"] >= endpoint_as_startpoint["slack"]:
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
        else:
            pipeline_mask, success = shift_pipeline_bit(endpoint.pipeline_mask, endpoint.pipeline_stage, left=False)
            if success:
                return startpoint.pipeline_mask, startpoint.pipeline_stage, pipeline_mask, endpoint.pipeline_stage - 1
            else:
                print("Warning: Unable to shift pipeline bit right. Trying to shift left.")
                pipeline_mask, success = shift_pipeline_bit(startpoint.pipeline_mask, startpoint.pipeline_stage, left=True)
                if success:
                    return pipeline_mask, startpoint.pipeline_stage + 1, endpoint.pipeline_mask, endpoint.pipeline_stage
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


def find_pipeline_stage(module_name, top_module="top", iterations=None):
    with open(f"./openlane_run/raw_netlist.json", 'r') as f:
        data = json.load(f)
    module_key = data["modules"][top_module]["cells"][module_name]["type"]
    
    datawidth = int(data["modules"][module_key]["parameter_default_values"]["DATAWIDTH"], 2)
    instance_id = int(data["modules"][module_key]["parameter_default_values"]["INSTANCE_ID"], 2)
    num_pipeline_stages = int(data["modules"][module_key]["parameter_default_values"]["NUM_PIPELINE_STAGES"], 2)
    
    rest_data = data["modules"][module_key]["cells"]
    filtered_data = {k: v for k, v in rest_data.items() if "_pipeline_stage" in k}

    pipeline_mask = {}
    for key in filtered_data.keys():
        if "ENABLE" in filtered_data[key]["type"]:
            idx = num_pipeline_stages - 1 - int(re.findall(r'\[(\d+)\]', key)[0])
            pipeline_mask[idx] = filtered_data[key]["type"][-1]

    mask = "".join(pipeline_mask[key] for key in sorted(pipeline_mask))
    return len(mask), mask, instance_id, num_pipeline_stages


def remove_duplicates_keep_lowest_slack(data):
    best = {}
    for entry in data:
        if entry['startpoint'] == "REGISTER" or entry['endpoint'] == "REGISTER":
            continue
        sp = entry['startpoint']
        ep = entry['endpoint']
        slack = entry['slack']
        key = (sp, ep)

        current_best = best.get(key)
        if current_best is None or slack < current_best['slack']:
            best[key] = entry

    return list(best.values())


def the_algorithm(condition, telemetry):
    # Get Data
    iterations = telemetry["iterations"]
    metrics = TimingRptParser(f"./openlane_run/{2*iterations+2}-openroad-staprepnr/{condition}/max.rpt")
    instance_details = metrics.get_instance_details() 
    simplified = remove_duplicates_keep_lowest_slack(instance_details)

    # Process Data
    for i, details in enumerate(simplified):
        print(details["startpoint"])
        print(details["endpoint"])
        if details["startpoint"].module != "INPUT":
            details["startpoint"].num_pipeline_stages, details["startpoint"].pipeline_mask, details["startpoint"].instance_id, details["startpoint"].num_enabled_pipeline_stages = find_pipeline_stage(details["startpoint"].instance_name, top_module[0], iterations)

        if details["endpoint"].module != "OUTPUT":
            details["endpoint"].num_pipeline_stages, details["endpoint"].pipeline_mask, details["endpoint"].instance_id, details["endpoint"].num_enabled_pipeline_stages = find_pipeline_stage(details["endpoint"].instance_name, top_module[0], iterations)
    data_hash = hash(tuple(tuple(sorted(d.items())) for d in simplified))  # Compare hashs to see if we have tried this already. 

    # Setup and Update Telemetry
    temp_telemetry = copy.deepcopy(telemetry)
    temp_telemetry["iterations"] += 1  

    # Check for bad paths (Input to Register that is not closest, Register to Output that is not closest)
    for data in simplified:
        if data["startpoint"].module == "INPUT" and data["endpoint"].module != "OUTPUT":
            #Input to output path becaause of pipeline stages at top
            mask = data["endpoint"].pipeline_mask
            stage = data["endpoint"].pipeline_stage
            forward = mask[len(mask)-stage:]
            if "1" in forward:
                temp_telemetry["kill"] = True
                print("Kill Condition Met: Input to Register that is not closest")
        if data["endpoint"].module == "OUTPUT" and data["startpoint"].module != "INPUT": 
            #Input to output path becaause of pipeline stages at top
            mask = data["startpoint"].pipeline_mask
            stage = data["startpoint"].pipeline_stage
            forward = mask[:len(mask)-stage-1]
            if "1" in forward:
                temp_telemetry["kill"] = True 
                print("Kill Condition Met: Register to Output that is not closest")

    if data_hash in temp_telemetry["attempted_pipeline_combinations"]:
        if temp_telemetry["kill_count"] >= 3:
            temp_telemetry["kill"] = True
            return temp_telemetry
        temp_telemetry["kill_count"] += 1

    temp_telemetry["attempted_pipeline_combinations"].add(data_hash)

    violated_paths = [item for item in simplified if item["violated"]]
    violated_paths.sort(key=lambda x: x["slack"])  # Sorted by slack

    # Debug Statements
    print("============================================================")
    print(f"Input Telemetry: {telemetry}")
    print(f"Output Telemetry: {temp_telemetry}")
    print("============================================================")
    print("ALL REGISTER PATHS")
    for i in (simplified):
        print(i)
    print("============================================================")
    print("SORTED VIOLATED REGISTER PATHS")
    for i in (violated_paths):
        print(i)
    print("============================================================")
    print("MODIFIED PATHS")
    print("----------------")

    # Modify Files
    changed_modules = set()
    for data in violated_paths:
        print("Startpoint:", data["startpoint"].instance_id, data["startpoint"].module, data["startpoint"].pipeline_mask, data["startpoint"].pipeline_stage)
        print("Endpoint:", data["endpoint"].instance_id, data["endpoint"].module, data["endpoint"].pipeline_mask, data["endpoint"].pipeline_stage)
        print("Slack:", data["slack"])
        print("Violations:", data["violated"])

        if data["startpoint"].instance_id in changed_modules or data["endpoint"].instance_id in changed_modules:
            print("Already Modified This Iteration")
            print("----------------")
            continue
        else:
            module_file_location_startpoint = file_finder(data["startpoint"].module, design_paths + lib_paths)
            module_file_location_endpoint = file_finder(data["endpoint"].module, design_paths + lib_paths)

            pm1, _, pm2, _ = generate_pipeline_mask(data["startpoint"], data["endpoint"], simplified, temp_telemetry)

            print(f"Startpoint File Location: {module_file_location_startpoint}")  
            print(f"Endpoint File Location: {module_file_location_endpoint}")
            print(f"Startpoint Pipeline Mask Change:", data["startpoint"].pipeline_mask, "to", pm1)
            print(f"Endpoint Pipeline Mask Change:", data["endpoint"].pipeline_mask, "to", pm2)
            print("----------------")
            
            if pm1 != data["startpoint"].pipeline_mask:
                modify_pipeline_mask(data["startpoint"].instance_id, pm1, module_file_location_startpoint)
                changed_modules.add(data["startpoint"].instance_id)
            if pm2 != data["endpoint"].pipeline_mask:
                modify_pipeline_mask(data["endpoint"].instance_id, pm2, module_file_location_endpoint)
                changed_modules.add(data["endpoint"].instance_id)
    print("============================================================")       
    return temp_telemetry


'''
SYNTHESIS
'''
flag_stop = False
telemetry = {"attempted_pipeline_combinations":set(), "kill_count":0, "kill":False, "iterations":0}
while not flag_stop:
    backup_files = create_backup_files(design_paths)
    for iterations in range(N_iterations):
        print_available_steps()

        # Dumping raw netlist
        verilog_str = " ".join(FILES)
        tel_it = telemetry["iterations"]
        yosys_cmd = f'mkdir -p ./openlane_run/{2*tel_it+1}-yosys-synthesis; yosys -p "read_verilog -sv {verilog_str}; hierarchy -top {top_module[0]}; proc; write_json ./openlane_run/raw_netlist.json"'
        # Run Yosys comman
        subprocess.run(yosys_cmd, shell=True, check=True)
        print("Yosys ran successfully!")

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
            SYNTH_HIERARCHY_MODE="deferred_flatten",
            SYNTH_STRATEGY="DELAY 1",        #Optimize for timing
            SYNTH_ABC_DFF=True,              # Enable flip-flop retiming
            SYNTH_ABC_USE_MFS3=True,         # Experimental SAT-based remapping
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
        iterations = telemetry["iterations"]
        stateout = StateOutMetrics(f"./openlane_run/{2*iterations+2}-openroad-staprepnr/state_out.json")
        if stateout.nom_ss_100C_1v60.metrics["timing__hold__ws"] < 0 or stateout.nom_ss_100C_1v60.metrics["timing__setup__ws"] < 0:
            print("Timing Violated For nom_ss_100C_1v60")
            temp_telemetry = the_algorithm("nom_ss_100C_1v60",  telemetry)
            if temp_telemetry["kill"]:
                print("Kill Condition Met")
                print(temp_telemetry)
                break
            telemetry = temp_telemetry
        else:
            print("Timing Passed For nom_ss_100C_1v60")
            print(clock_period)
            print(telemetry) 
            flag_stop = True
            break
        # input()
    
    if not flag_stop:
        restore_backup_files(backup_files)
        telemetry["attempted_pipeline_combinations"].clear()
        telemetry["kill_count"] = 0
        telemetry["kill"] = False
        clock_period += 0.2
        input("Press Enter To Continue With Increased Clock Period...")





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
