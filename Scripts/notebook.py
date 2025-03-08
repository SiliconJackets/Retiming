import openlane
from openlane.config import Config
from openlane.steps import Step
from openlane.state import State
import os

from dotenv import load_dotenv
load_dotenv(".env")

from metrics import TimingRptParser

'''
CONFIGURATIONS
'''
FILES = ["./verilog_files/spm.v"]
Config.interactive(
    "spm",
    PDK="sky130A",
    PDK_ROOT=os.getenv("VOLARE_FOLDER"),  # create .env file with VOLARE_FOLDER=<path to skywater-pdk>
    CLOCK_PORT="clk",
    CLOCK_NET="clk",
    CLOCK_PERIOD=10,
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

'''
metrics = StateOutMetrics("./openlane_run/2-openroad-staprepnr/state_out.json")
print(metrics)

# Can also indidually access metrics for different cases. 
#     metrics.global_metrics    // Overall Group
#     metrics.nom_tt_025C_1v80  // self explanatory
#     metrics.nom_ss_100C_1v60  // self explanatory
#     metrics.nom_ff_n40C_1v95  // self explanatory
'''
