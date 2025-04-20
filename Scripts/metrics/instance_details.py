import re


class InstanceDetails:
    def __init__(self, string, startpoint=True):
        self.module, self.instance_name, self.pipeline_stage = self.pattern_match(string, startpoint)
        self.pipeline_mask = None
        self.num_pipeline_stages = None
        self.instance_id = None
        self.num_enabled_pipeline_stages = None

    def pattern_match(self, string, startpoint=False):
        patterns = [
            r'(.*?)\.([^.]+)_pipeline_stage\[(\d+)\]',
            r'(.*?)/([^.]+)_pipeline_stage\[(\d+)\]'
        ]

        for pattern in patterns:
            match = re.search(pattern, string)
            if match:
                instance_name, module, stage = match.groups()
                return module, instance_name, int(stage)

        if startpoint and string == "INPUT":
            return "INPUT", "INPUT", None
        elif not startpoint and string == "OUTPUT":
            return "OUTPUT", "OUTPUT", None
        else:
            return "REGISTER", "REGISTER", None
    
    def __repr__(self):
        return f"""InstanceDetails(module={self.module}, instance_name={self.instance_name}, instance_id={self.instance_id}, num_pipeline_stages={self.num_pipeline_stages}, pipeline_stage={self.pipeline_stage}, pipeline_mask={self.pipeline_mask}, num_enabled_pipeline_stages={self.num_enabled_pipeline_stages})"""

    # Added for hashability and equality
    def __eq__(self, other):
        if not isinstance(other, InstanceDetails):
            return False
        return self.__dict__ == other.__dict__

    def __hash__(self):
        # Convert to a tuple of key-value pairs sorted for consistent hashing
        return hash(tuple(sorted(self.__dict__.items())))