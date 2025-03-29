def modify_mask(file_path, mask):
    with open(file_path, 'r') as file:
        lines = file.readlines()

    with open(file_path, 'w') as file:
        for line in lines:
            if line.lstrip().startswith("localparam PIPELINE_STAGE_MASK"):
                indent = line[:len(line) - len(line.lstrip())]
                line = f"{indent}localparam PIPELINE_STAGE_MASK = {len(mask)}'b{mask};\n"
            file.write(line)
            

modify_mask("/mnt/c/home/CaC_Spring25/Scripts/../Design/Multiplier//array_multiplier.sv", "1111") 