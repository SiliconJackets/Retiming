from metrics import InstanceDetails


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


def generate_pipeline_mask(startpoint: InstanceDetails, endpoint: InstanceDetails):
    """
    Generate pipeline mask based on the timing path between startpoint and endpoint.
    
    Args:
        startpoint: InstanceDetails object for the startpoint
        endpoint: InstanceDetails object for the endpoint
        
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



# Input to Register
def i2r():
    print("INPUT TO REGISTER")
    startpoint = InstanceDetails(string="startpoint", startpoint=True)
    endpoint = InstanceDetails(string="endpoint", startpoint=False)
    endpoint.module = "REGISTER"
    endpoint.instance_name = "mul1"
    endpoint.instance_id = 0
    endpoint.num_pipeline_stages = 6
    endpoint.num_enabled_pipeline_stages = 3

    endpoint.pipeline_stage =  1
    endpoint.pipeline_mask = "100110"
    print(startpoint)
    print(endpoint)
    print(generate_pipeline_mask(startpoint, endpoint))

    endpoint.pipeline_stage =  0
    endpoint.pipeline_mask = "100011"
    print(startpoint)
    print(endpoint)
    print(generate_pipeline_mask(startpoint, endpoint))


# Register to Output
def r2o():
    print("REGISTER TO OUTPUT")
    startpoint = InstanceDetails(string="startpoint", startpoint=True)
    endpoint = InstanceDetails(string="endpoint", startpoint=False)
    startpoint.module = "REGISTER"
    endpoint.instance_name = "mul1"
    startpoint.instance_id = 0
    startpoint.num_pipeline_stages = 6
    startpoint.num_enabled_pipeline_stages = 3

    startpoint.pipeline_stage =  5
    startpoint.pipeline_mask = "100110"
    print(startpoint)
    print(endpoint)
    print(generate_pipeline_mask(startpoint, endpoint))

    startpoint.pipeline_stage =  4
    startpoint.pipeline_mask = "010011"
    print(startpoint)
    print(endpoint)
    print(generate_pipeline_mask(startpoint, endpoint))

    startpoint.pipeline_stage =  3
    startpoint.pipeline_mask = "001011"
    print(startpoint)
    print(endpoint)
    print(generate_pipeline_mask(startpoint, endpoint))


# Register to Register (same module)
def r2r_s():
    print("REGISTER TO REGISTER (same module)")
    startpoint = InstanceDetails(string="startpoint", startpoint=True)
    endpoint = InstanceDetails(string="endpoint", startpoint=False)
    startpoint.module = "REGISTER"
    startpoint.instance_name = "mul1"
    startpoint.instance_id = 0
    startpoint.num_pipeline_stages = 6
    startpoint.num_enabled_pipeline_stages = 3

    endpoint.module = startpoint.module
    endpoint.instance_name = startpoint.instance_name
    endpoint.instance_id = startpoint.instance_id
    endpoint.num_pipeline_stages = startpoint.num_pipeline_stages
    endpoint.num_enabled_pipeline_stages = startpoint.num_enabled_pipeline_stages


# Register to Register (different module)
def r2r_d():
    print("REGISTER TO REGISTER (different module)")
    startpoint = InstanceDetails(string="startpoint", startpoint=True)
    endpoint = InstanceDetails(string="endpoint", startpoint=False)


# i2r()
# print("======================================")
# r2o()
# r2r_s()
# r2r_d()

