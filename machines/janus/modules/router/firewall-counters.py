"""nftables named counters as a Prometheus textfile."""

import json
import os
import subprocess
import sys
import tempfile


def label_value(value):
    return str(value).replace("\\", "\\\\").replace("\n", "\\n").replace('"', '\\"')


def metric_line(metric, labels, value):
    label_text = ",".join(f'{key}="{label_value(labels[key])}"' for key in sorted(labels))
    return f"{metric}{{{label_text}}} {int(value)}\n"


def load_counters():
    ruleset = json.loads(subprocess.check_output(["nft", "-j", "list", "ruleset"], text=True))
    counters = {}
    for item in ruleset.get("nftables", []):
        counter = item.get("counter") if isinstance(item, dict) else None
        if counter is None:
            continue
        key = (counter.get("family"), counter.get("table"), counter.get("name"))
        counters[key] = counter
    return counters


def main(counters_path, output_path):
    with open(counters_path, encoding="utf-8") as counters_file:
        counters = json.load(counters_file)

    observed = load_counters()
    output_directory = os.path.dirname(output_path)
    os.makedirs(output_directory, mode=0o755, exist_ok=True)
    descriptor, temporary_path = tempfile.mkstemp(
        prefix=os.path.basename(output_path) + ".", dir=output_directory, text=True
    )
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as output:
            os.fchmod(output.fileno(), 0o644)
            output.write("# HELP janus_firewall_counter_packets_total Packets matched by Janus nftables named counters.\n")
            output.write("# TYPE janus_firewall_counter_packets_total counter\n")
            output.write("# HELP janus_firewall_counter_bytes_total Bytes matched by Janus nftables named counters.\n")
            output.write("# TYPE janus_firewall_counter_bytes_total counter\n")
            for counter in counters:
                key = (counter["family"], counter["table"], counter["name"])
                values = observed.get(key, {})
                labels = {
                    "family": counter["family"],
                    "table": counter["table"],
                    "chain": counter["chain"],
                    "counter": counter["name"],
                    "action": counter["action"],
                }
                output.write(metric_line("janus_firewall_counter_packets_total", labels, values.get("packets", 0)))
                output.write(metric_line("janus_firewall_counter_bytes_total", labels, values.get("bytes", 0)))
        os.replace(temporary_path, output_path)
        temporary_path = None
    finally:
        if temporary_path is not None:
            try:
                os.unlink(temporary_path)
            except FileNotFoundError:
                pass


if __name__ == "__main__":
    main(*sys.argv[1:])
