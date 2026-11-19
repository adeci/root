"""Each lease Kea has in use, as a Prometheus textfile: when it was last renewed, and its client's name where that is shown."""

import json
import socket
import sys
from pathlib import Path

# Kea's state for a lease in use; the others are declined, expired or released.
IN_USE = 0


def escape_label(value):
    return str(value).replace("\\", "\\\\").replace("\n", "\\n").replace('"', '\\"')


def leases(socket_path):
    with socket.socket(socket.AF_UNIX) as connection:
        # A Kea that accepts and never answers fails this run, and the next one asks again.
        connection.settimeout(5)
        connection.connect(socket_path)
        connection.sendall(json.dumps({"command": "lease4-get-all"}).encode())
        # Kea closes the connection once it has answered.
        reply = json.loads(connection.makefile().read())
    # 3 is Kea's answer when it holds no lease.
    if reply["result"] not in (0, 3):
        raise RuntimeError(reply.get("text", "lease4-get-all failed"))
    return reply["arguments"]["leases"]


def main(socket_path, settings_path, output_path):
    settings = json.loads(Path(settings_path).read_text())
    private_subnets = set(settings["privateSubnets"])
    reserved_addresses = set(settings["reservedAddresses"])
    lines = [
        "# HELP janus_dhcp_lease_renewed_timestamp_seconds When each lease in use was last renewed, named as its reservation or, off the guest and tenant networks, as its client asked.",
        "# TYPE janus_dhcp_lease_renewed_timestamp_seconds gauge",
    ]
    for lease in leases(socket_path):
        if lease["state"] != IN_USE:
            continue
        labels = {"address": lease["ip-address"], "mac": lease["hw-address"]}
        # A name given fully qualified ends in the root's dot.
        hostname = lease["hostname"].removesuffix(".")
        if hostname and (lease["subnet-id"] not in private_subnets or lease["ip-address"] in reserved_addresses):
            labels["hostname"] = hostname
        label_text = ",".join(f'{key}="{escape_label(value)}"' for key, value in labels.items())
        lines.append(f"janus_dhcp_lease_renewed_timestamp_seconds{{{label_text}}} {lease['cltt']}")

    output = Path(output_path)
    temporary = output.with_suffix(".prom.tmp")
    temporary.write_text("\n".join(lines) + "\n")
    temporary.chmod(0o644)
    temporary.replace(output)


if __name__ == "__main__":
    main(*sys.argv[1:])
