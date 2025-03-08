import re

class MaxRptParser:
    def __init__(self, file_path: str = None, file_content: str = None):
        """
        Initialize the parser. You must provide either a file path or the file content.
        
        :param file_path: Path to the .rpt file.
        :param file_content: The full text content of the .rpt file.
        """
        if file_content is not None:
            self.file_content = file_content
        elif file_path is not None:
            with open(file_path, "r") as f:
                self.file_content = f.read()
        else:
            raise ValueError("Either file_path or file_content must be provided.")
        
        self.paths = []  # List to store parsed path information

    def parse(self):
        """
        Parse the file content to capture all information from each path block.
        
        Each block (starting with a valid 'Startpoint:') will produce a dictionary with:
            - startpoint_signal: signal name from the Startpoint line.
            - startpoint_comment: any comment (text inside parentheses) on the Startpoint line.
            - endpoint_signal: signal name from the Endpoint line.
            - endpoint_comment: any comment on the Endpoint line (even if on the next line).
            - path_group: the value following "Path Group:".
            - path_type: the value following "Path Type:".
            - table: a raw string capturing the timing table and related lines.
            - slack: the slack value (as float) if found.
            - violated: True if slack is negative, else False.
            - raw: the entire raw block text.
        """
        # Split the file content into blocks that start with "Startpoint:"
        blocks = re.split(r'(?=Startpoint:)', self.file_content)
        # Filter out any block that doesn't actually start with "Startpoint:" (after stripping)
        blocks = [block for block in blocks if block.lstrip().startswith("Startpoint:")]

        for block in blocks:
            entry = {}
            entry['raw'] = block.strip()

            # Parse Startpoint: capture signal and an optional comment in parentheses.
            sp_match = re.search(r'^Startpoint:\s*(\S+)(?:\s*\((.*?)\))?', block, re.MULTILINE)
            if sp_match:
                entry['startpoint_signal'] = sp_match.group(1)
                entry['startpoint_comment'] = sp_match.group(2) if sp_match.group(2) else ""
            else:
                entry['startpoint_signal'] = None
                entry['startpoint_comment'] = ""

            # Parse Endpoint: capture signal and optionally a comment that may be on the same or next line.
            ep_match = re.search(r'^Endpoint:\s*(\S+)(?:\s*\n\s*\((.*?)\))?', block, re.MULTILINE)
            if ep_match:
                entry['endpoint_signal'] = ep_match.group(1)
                entry['endpoint_comment'] = ep_match.group(2) if ep_match.group(2) else ""
            else:
                entry['endpoint_signal'] = None
                entry['endpoint_comment'] = ""

            # Parse Path Group and Path Type
            pg_match = re.search(r'^Path Group:\s*(.*)$', block, re.MULTILINE)
            entry['path_group'] = pg_match.group(1).strip() if pg_match else ""

            pt_match = re.search(r'^Path Type:\s*(.*)$', block, re.MULTILINE)
            entry['path_type'] = pt_match.group(1).strip() if pt_match else ""

            # Capture table details: we try to get everything from the "Fanout" header until the slack line.
            table_match = re.search(r'(Fanout.*?)(?=^\s*[-\d\.]+\s+slack|\Z)', block, re.DOTALL | re.MULTILINE)
            entry['table'] = table_match.group(1).strip() if table_match else ""

            # Capture slack: if multiple slack lines are present, use the last one.
            slack_matches = re.findall(r'^\s*([-\d\.]+)\s+slack', block, re.MULTILINE)
            if slack_matches:
                try:
                    slack_value = float(slack_matches[-1])
                except ValueError:
                    slack_value = None
            else:
                slack_value = None

            entry['slack'] = slack_value
            entry['violated'] = (slack_value is not None and slack_value < 0)

            # Append the captured entry to the paths list.
            self.paths.append(entry)

    def get_paths(self):
        """
        Return a list of dictionaries with all captured information for each path.
        """
        return self.paths


# Example usage:
if __name__ == "__main__":
    # Provide the path to your .rpt file
    file_path = "./openlane_run/2-openroad-staprepnr/nom_ff_n40C_1v95/max_10_critical.rpt"
    
    # Create the parser instance (file reading is integrated)
    parser = MaxRptParser(file_path=file_path)
    
    # Parse the file
    parser.parse()
    
    # Print the parsed information for each path block
    for path in parser.get_paths():
        print("=====================================")
        print("Startpoint:", path['startpoint_signal'], path['startpoint_comment'])
        print("Endpoint:", path['endpoint_signal'], path['endpoint_comment'])
        print("Path Group:", path['path_group'])
        print("Path Type:", path['path_type'])
        print("Slack:", path['slack'], "Violates:" , path['violated'])
        print("Table Details:")
        print(path['table'])
        print("Raw Block:")
        print(path['raw'])
        print("=====================================\n")


