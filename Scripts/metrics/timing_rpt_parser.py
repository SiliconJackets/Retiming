import re
from metrics import InstanceDetails


class TimingRptParser:
    def __init__(self, timing_rpt: str = None):
        """
        Initialize the parser with the contents of a max report file.
        :param timing_rpt: The .rpt file.
        """
        if timing_rpt is None:
            raise ValueError("No timing report file provided.")
        else:
            with open(timing_rpt, 'r') as f:
                self.timing_rpt = f.read()
        self.paths = []  # List to store parsed path information

        self.parse()

    def parse(self):
        """
        Parse the file content to extract the startpoint, endpoint, slack value,
        and whether the slack is violated (negative) for each path.
        """
        # Split the file content into blocks that start with "Startpoint:" and filter out empty blocks
        blocks = re.split(r'(?=Startpoint:)', self.timing_rpt)
        blocks = [block for block in blocks if block.lstrip().startswith("Startpoint:")]
        for block in blocks:
            block = block.strip()
            if not block:
                continue

            startpoint_match = re.search(r'^Startpoint:\s*(\S+)\s*\n?\s*\((\w+)', block, re.MULTILINE)
            startpoint = startpoint_match.group(1) if startpoint_match else None
            input_io_type = startpoint_match.group(2) if startpoint_match else None

            endpoint_match = re.search(r'^Endpoint:\s*(\S+)\s*\n?\s*\((\w+)', block, re.MULTILINE)
            endpoint = endpoint_match.group(1) if endpoint_match else None
            output_io_type = endpoint_match.group(2) if startpoint_match else None

            slack_match = re.search(r'^\s*([-\d\.]+)\s+slack', block, re.MULTILINE)
            if slack_match:
                try:
                    slack_value = float(slack_match.group(1))
                except ValueError:
                    slack_value = None
            else:
                slack_value = None

            # Determine if the slack is violated (negative slack)
            violated = slack_value is not None and slack_value < 0

            # Store the parsed information in the paths list
            self.paths.append({
                'startpoint': startpoint if input_io_type != "input" else "INPUT",
                'endpoint': endpoint if output_io_type != "output" else "OUTPUT",
                'slack': slack_value,
                'violated': violated
            })

    def get_paths(self):
        """
        Return a list of dictionaries where each dictionary contains:
        - 'startpoint': The startpoint of the path.
        - 'endpoint': The endpoint of the path.
        - 'slack': The slack time (float) or None if not found.
        - 'violated': True if slack < 0, otherwise False (or None if slack not found).
        """
        return self.paths

    def get_instance_details(self): 
        instance_details = []
        for path in self.paths:
            startpoint = InstanceDetails(path["startpoint"], startpoint=True)
            endpoint = InstanceDetails(path["endpoint"], startpoint=False)
            instance_details.append({"startpoint": startpoint, "endpoint": endpoint, "slack": path["slack"], "violated": path["violated"]})
        
        return instance_details


