import re


class InstanceDetails:
    def __init__(self, string, startpoint=True):
        self.module, self.instance_name, self.pipeline_stage = self.pattern_match(string, startpoint)
        self.pipeline_mask = None
        self.num_pipeline_stages = None
        self.instance_id = None
        self.num_enabled_pipeline_stages = None

    def pattern_match(self, string, startpoint=True):
        pattern = r'/([^/_]+)_pipeline_stage'
        match = re.search(pattern, string)
        if match:
            module = match.group(1)
            instance_name = string[:string.find(f"/{module}")]
            pattern = r'_pipeline_stage\[(?P<number>\d+)\]'
            match = re.search(pattern, string)
            pipeline_stage = int(match.group('number'))
        elif startpoint:
            module = "INPUT"
            instance_name = "INPUT"
            pipeline_stage = None
        else:
            module = "OUTPUT"
            instance_name = "OUTPUT"
            pipeline_stage = None
        return module, instance_name, pipeline_stage
    
    def __repr__(self):
        return f"""InstanceDetails(module={self.module}, instance_name={self.instance_name}, instance_id={self.instance_id}, num_pipeline_stages={self.num_pipeline_stages}, pipeline_stage={self.pipeline_stage}, pipeline_mask={self.pipeline_mask}, num_enabled_pipeline_stages={self.num_enabled_pipeline_stages})"""
