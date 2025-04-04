import json


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
