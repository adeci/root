"""nftables named counters as a Prometheus textfile."""

import json
import subprocess
import sys
from pathlib import Path


def label_value(value):
    return str(value).replace("\\", "\\\\").replace("\n", "\\n").replace('"', '\\"')


def metric_line(metric, labels, value):
    label_text = ",".join(f'{key}="{label_value(labels[key])}"' for key in sorted(labels))
    return f"{metric}{{{label_text}}} {int(value)}"


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
    counters = json.loads(Path(counters_path).read_text())
    observed = load_counters()
    lines = [
        "# HELP janus_firewall_counter_packets_total Packets matched by Janus nftables named counters.",
        "# TYPE janus_firewall_counter_packets_total counter",
        "# HELP janus_firewall_counter_bytes_total Bytes matched by Janus nftables named counters.",
        "# TYPE janus_firewall_counter_bytes_total counter",
    ]
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
        lines.append(metric_line("janus_firewall_counter_packets_total", labels, values.get("packets", 0)))
        lines.append(metric_line("janus_firewall_counter_bytes_total", labels, values.get("bytes", 0)))

    output = Path(output_path)
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_suffix(".prom.tmp")
    temporary.write_text("\n".join(lines) + "\n")
    temporary.chmod(0o644)
    temporary.replace(output)


if __name__ == "__main__":
    main(*sys.argv[1:])
