import os
import re
import sys

if len(sys.argv) != 2:
    print("Usage: python3 link_files.py <include_file_location>")
    sys.exit(1)

# Input and output file names
input_file = "Include/" + sys.argv[1]
print("looking in file " + input_file)

# Ensure WORKSPACE and sym_links directories exist
workspace_dir = "WORKSPACE"
sym_links_dir = os.path.join(workspace_dir, "sym_links")
os.makedirs(sym_links_dir, exist_ok=True)

# Output file path in WORKSPACE
output_file = os.path.join(sym_links_dir, "sim_no_path.include")


# Open input file for reading
with open(input_file, 'r') as input_fp:
    # Open output file for writing
    with open(output_file, 'w') as output_fp:
        # Iterate through each line in the input file
        for line in input_fp:
            # Remove leading and trailing whitespaces
            line = line.strip()

            # Check if the line is a comment or empty
            if not line or line.startswith('//'):
                # If it's a comment or empty line, write it directly to the output file
                output_fp.write(line + '\n')
            else:
                # Extract the file path using regex
                match = re.match(r'^\s*(\S+)\s*$', line)
                if match:
                    file_path = match.group(1)

                    # Check if the file exists
                    if os.path.exists(file_path):
                        # Create symbolic link in WORKSPACE
                        link_path = os.path.join(sym_links_dir, os.path.basename(file_path))
                        os.symlink(os.path.abspath(file_path), link_path)

                        # Write only the filename to the output file
                        output_fp.write(f"sym_links/{os.path.basename(file_path)}\n")
                    else:
                        print(f"Error: File '{file_path}' does not exist. Aborting process.")
                        break
                else:
                    print(f"Error: Invalid file path format in line '{line}'. Aborting process.")
                    break
