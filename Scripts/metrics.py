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


# TODO: Instead of saving "table" as a raw string, parse it into a more structured format.
class TimingRptParserAll:
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

    def __parse_table(self, table: str):
        def parse_line(line):
            """Extracts fields from a line based on the computed column boundaries."""
            fields = {}
            for key, (start, end) in cols.items():
                val = line[start:] if end == -1 else line[start:end]
                val = val.strip()
                fields[key] = val if val != "" else None
            return fields
        
        lines = table.strip().splitlines()
        header_line = lines[0]
        cols = {
            "Fanout": (header_line.index("Fanout"), header_line.index("Fanout") + len("Fanout")),
            "Cap": (header_line.index("Fanout") + len("Fanout"), header_line.index("Cap") + len("Cap")),
            "Slew": (header_line.index("Cap") + len("Cap"), header_line.index("Slew") + len("Slew")),
            "Delay": (header_line.index("Slew") + len("Slew"), header_line.index("Delay") + len("Delay")),
            "Time": (header_line.index("Delay") + len("Delay"), header_line.index("Time") + len("Time")),
            "Description": (header_line.index("Time") + len("Time"), -1),
        }

        rows = []
        current_row = None
        data_lines = lines[1:]

        for line in data_lines:
            line = line.rstrip()
            if set(line.strip()) == {"-"}:
                continue
            
            parsed = parse_line(line)
            if (parsed["Fanout"] is None and parsed["Cap"] is None and parsed["Slew"] is None and 
                parsed["Delay"] is None and parsed["Time"] is None and parsed["Description"] is not None):
                if current_row is not None:
                    current_row["Description"] += " " + parsed["Description"]
                continue   
            current_row = parsed
            rows.append(current_row)

        for row in rows:
            for col in ["Fanout", "Cap", "Slew", "Delay", "Time"]:
                if row[col] is not None:
                    try:
                        row[col] = float(row[col])
                    except ValueError:
                        pass

        return rows              

    def parse(self):
        """
        Parse the file content to capture all information from each path block.
        
        Each block (starting with a valid 'Startpoint:') will produce a dictionary with:
            - startpoint: signal name from the Startpoint line.
            - startpoint_comment: any comment (text inside parentheses) on the Startpoint line.
            - endpoint: signal name from the Endpoint line.
            - endpoint_comment: any comment on the Endpoint line (even if on the next line).
            - path_group: the value following "Path Group:".
            - path_type: the value following "Path Type:".
            - table: a raw string capturing the timing table and related lines.
            - slack: the slack value (as float) if found.
            - violated: True if slack is negative, else False.
        """
        # Split the file content into blocks that start with "Startpoint:"
        blocks = re.split(r'(?=Startpoint:)', self.timing_rpt)
        # Filter out any block that doesn't actually start with "Startpoint:" (after stripping)
        blocks = [block for block in blocks if block.lstrip().startswith("Startpoint:")]

        for block in blocks:
            entry = {}

            startpoint_match = re.search(r'^Startpoint:\s*(\S+)(?:\s*\((.*?)\))?', block, re.MULTILINE)
            if startpoint_match:
                entry['startpoint'] = startpoint_match.group(1)
                entry['startpoint_comment'] = startpoint_match.group(2) if startpoint_match.group(2) else ""
            else:
                entry['startpoint_signal'] = None
                entry['startpoint_comment'] = ""

            endpoint_match = re.search(r'^Endpoint:\s*(\S+)(?:\s*\n\s*\((.*?)\))?', block, re.MULTILINE)
            if endpoint_match:
                entry['endpoint'] = endpoint_match.group(1)
                entry['endpoint_comment'] = endpoint_match.group(2) if endpoint_match.group(2) else ""
            else:
                entry['endpoint'] = None
                entry['endpoint_comment'] = ""

            pathgroup_match = re.search(r'^Path Group:\s*(.*)$', block, re.MULTILINE)
            entry['path_group'] = pathgroup_match.group(1).strip() if pathgroup_match else ""

            pathtype_match = re.search(r'^Path Type:\s*(.*)$', block, re.MULTILINE)
            entry['path_type'] = pathtype_match.group(1).strip() if pathtype_match else ""

            table_match = re.search(r'(Fanout.*?)(?=^\s*[-\d\.]+\s+slack|\Z)', block, re.DOTALL | re.MULTILINE)
            entry['table'] = self.__parse_table(table_match.group(1).strip() if table_match else "")

            slack_match = re.findall(r'^\s*([-\d\.]+)\s+slack', block, re.MULTILINE)
            if slack_match:
                try:
                    slack_value = float(slack_match[-1])
                except ValueError:
                    slack_value = None
            else:
                slack_value = None

            entry['slack'] = slack_value
            entry['violated'] = (slack_value is not None and slack_value < 0)

            self.paths.append(entry)

    def get_paths(self):
        """
        Return a list of dictionaries with all captured information for each path.
        """
        return self.paths