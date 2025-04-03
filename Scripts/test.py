from metrics import InstanceDetails

def generate_pipeline_mask(startpoint: InstanceDetails, endpoint: InstanceDetails):
    if startpoint.module == "INPUT":
        current_mask = endpoint.pipeline_mask
        pipeline_mask = endpoint.pipeline_mask
    elif endpoint.module == "OUTPUT":
        pass
    else:
        pass