import openlane
from openlane.config import Config
from openlane.steps import Step
from openlane.state import State
import os

from dotenv import load_dotenv
load_dotenv(".env")

from metrics import TimingRptParser

### Make Changes here ###
cwd_path = os.getcwd()
## Design Modules
design_modules = ["array_multiplier"]
design_paths = [f"{cwd_path}/../Design/Multiplier//{design_module}.sv" for design_module in design_modules]
## Library Modules
lib_modules = ["pipeline_stage"]
lib_paths = [f"{cwd_path}/../Design/lib/{lib_module}.sv" for lib_module in lib_modules]
## Clock pin name
clock_pin = "clk"
##Clock period
clock_period = 1
## No changes bellow this line ###

'''
CONFIGURATIONS
'''
FILES = [path for path in design_paths + lib_paths if path]
Config.interactive(
    design_modules[0],
    PDK="sky130A",
    PDK_ROOT=os.getenv("VOLARE_FOLDER"),  # create .env file with VOLARE_FOLDER=<path to skywater-pdk>
    CLOCK_PORT = clock_pin,
    CLOCK_NET = clock_pin,
    CLOCK_PERIOD = clock_period,
    PRIMARY_GDSII_STREAMOUT_TOOL="klayout",
)

'''
AVAILABLE STEPS
'''
# Print the version of OpenLANE
print(f"Openlane2 Version: {openlane.__version__}")
# List all available steps
available_steps = Step.factory.list()
print(available_steps)

'''
SYNTHESIS
'''
Synthesis = Step.factory.get("Yosys.Synthesis")
synthesis = Synthesis(
    VERILOG_FILES=FILES,
    state_in=State(),
)
synthesis.start()

# Static Timing Analysis Pre-PNR (STA Pre-PNR)
STAPrePNR = Step.factory.get("OpenROAD.STAPrePNR")
sta_pre_pnr = STAPrePNR(
    VERILOG_FILES=FILES,
    state_in=synthesis.state_out,  # Use the output state from synthesis as input state for STA Pre-PNR
)
sta_pre_pnr.start()

# Parse Timing Data.
metrics = TimingRptParser("./openlane_run/2-openroad-staprepnr/nom_ff_n40C_1v95/max_10_critical.rpt")
metrics.parse()
print(metrics.get_paths())
