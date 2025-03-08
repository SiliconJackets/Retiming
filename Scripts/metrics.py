import json
import re

class StateOutMetrics:
    def __init__(self, json_file: str):
        # Load the JSON file
        with open(json_file, 'r') as f:
            data = json.load(f)
        all_metrics = data.get("metrics", {})

        # Global metrics (those without a specific corner)
        self.global_metrics = {k: v for k, v in all_metrics.items() if "corner:" not in k}

        # Create corner-specific metrics objects
        self.nom_tt_025C_1v80 = StateOutCornerMetrics("nom_tt_025C_1v80", all_metrics)
        self.nom_ss_100C_1v60 = StateOutCornerMetrics("nom_ss_100C_1v60", all_metrics)
        self.nom_ff_n40C_1v95 = StateOutCornerMetrics("nom_ff_n40C_1v95", all_metrics)

    def __repr__(self):
        return (f"Global Metrics: {self.global_metrics}\n"
                f"nom_tt_025C_1v80: {self.nom_tt_025C_1v80}\n"
                f"nom_ss_100C_1v60: {self.nom_ss_100C_1v60}\n"
                f"nom_ff_n40C_1v95: {self.nom_ff_n40C_1v95}")


class StateOutCornerMetrics:
    def __init__(self, corner: str, metrics: dict):
        self.corner = corner
        self.metrics = {}
        suffix = f"__corner:{corner}"
        # Iterate over all metrics and select those that match the current corner.
        for key, value in metrics.items():
            if suffix in key:
                # Remove the corner suffix to clean up the metric name.
                base_key = key.replace(suffix, "")
                self.metrics[base_key] = value

    def get_metric(self, metric_name: str):
        """Get a specific metric by its base name."""
        return self.metrics.get(metric_name)

    def __repr__(self):
        return str(self.metrics)


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

            startpoint_match = re.search(r'^Startpoint:\s*(\S+)', block, re.MULTILINE)
            startpoint = startpoint_match.group(1) if startpoint_match else None

            endpoint_match = re.search(r'^Endpoint:\s*(\S+)', block, re.MULTILINE)
            endpoint = endpoint_match.group(1) if endpoint_match else None

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
                'startpoint': startpoint,
                'endpoint': endpoint,
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
