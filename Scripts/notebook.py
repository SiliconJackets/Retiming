import openlane
from openlane.config import Config
from openlane.steps import Step
from openlane.state import State
import json


class Metrics:
    def __init__(self, json_file: str):
        # Load the JSON file
        with open(json_file, 'r') as f:
            data = json.load(f)
        all_metrics = data.get("metrics", {})

        # Global metrics (those without a specific corner)
        self.global_metrics = {k: v for k, v in all_metrics.items() if "corner:" not in k}

        # Create corner-specific metrics objects
        self.nom_tt_025C_1v80 = CornerMetrics("nom_tt_025C_1v80", all_metrics)
        self.nom_ss_100C_1v60 = CornerMetrics("nom_ss_100C_1v60", all_metrics)
        self.nom_ff_n40C_1v95 = CornerMetrics("nom_ff_n40C_1v95", all_metrics)

    def __repr__(self):
        return (f"Global Metrics: {self.global_metrics}\n"
                f"nom_tt_025C_1v80: {self.nom_tt_025C_1v80}\n"
                f"nom_ss_100C_1v60: {self.nom_ss_100C_1v60}\n"
                f"nom_ff_n40C_1v95: {self.nom_ff_n40C_1v95}")


class CornerMetrics:
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


'''
CONFIGURATIONS
'''
FILES = ["./verilog_files/spm.v"]
Config.interactive(
    "spm",
    PDK="sky130A",
    PDK_ROOT="/home/ethanhuang03/.volare",  # change it to whatever.
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
metrics = Metrics("./openlane_run/2-openroad-staprepnr/state_out.json")
print(metrics)
'''
Can also indidually access metrics for different cases. 
    metrics.global_metrics    // Overall Group
    metrics.nom_tt_025C_1v80  // self explanatory
    metrics.nom_ss_100C_1v60  // self explanatory
    metrics.nom_ff_n40C_1v95  // self explanatory
'''