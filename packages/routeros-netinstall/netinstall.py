import argparse
import atexit
import json
import os
import subprocess
import tempfile


def run(command, **kwargs):
    subprocess.run(command, check=True, **kwargs)


def output(command):
    return subprocess.check_output(command, text=True).strip()


def ethernet_interfaces():
    links = json.loads(output(["ip", "-j", "link", "show"]))
    return [
        (link["ifname"], link.get("operstate", "UNKNOWN"))
        for link in links
        if link.get("ifname", "").startswith(("en", "eth"))
    ]


def choose_interface():
    ifaces = ethernet_interfaces()
    if not ifaces:
        raise SystemExit("ERROR: No ethernet interfaces found.")

    print("Select the interface connected to the device:")
    print("")
    for index, (name, state) in enumerate(ifaces, start=1):
        print(f"  {index}) {name:<20} [{state}]")
    print("")

    try:
        choice = int(input("Enter number: ")) - 1
    except ValueError:
        raise SystemExit("ERROR: Invalid selection.")

    if choice < 0 or choice >= len(ifaces):
        raise SystemExit("ERROR: Invalid selection.")

    return ifaces[choice][0]


def cleanup(iface, setup_script):
    print("==> Cleaning up...")
    subprocess.run(
        ["sudo", "iptables", "-D", "nixos-fw", "-i", iface, "-j", "ACCEPT"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    subprocess.run(
        ["sudo", "ip", "addr", "del", "192.168.88.2/24", "dev", iface],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    if setup_script and os.path.exists(setup_script):
        os.unlink(setup_script)


def write_setup_script(dhcp_clients):
    print("==> Reading admin password from clan secrets...")
    password = output(["clan", "secrets", "get", "routeros-password"])

    fd, path = tempfile.mkstemp(prefix="routeros-setup-", suffix=".rsc", dir="/tmp")
    with os.fdopen(fd, "w") as script:
        script.write(f'/user set admin password="{password}"\n')
        for interface in dhcp_clients:
            script.write(f"/ip dhcp-client add interface={interface} disabled=no\n")
    return path


def main():
    parser = argparse.ArgumentParser(description="Run MikroTik RouterOS netinstall.")
    parser.add_argument("--device", required=True)
    parser.add_argument("--arch", required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--netinstall-cli", required=True)
    parser.add_argument("--package", action="append", required=True, dest="packages")
    parser.add_argument("--package-name", action="append", required=True, dest="package_names")
    parser.add_argument("--dhcp-client", action="append", required=True, dest="dhcp_clients")
    parser.add_argument("--installed-summary", required=True)
    parser.add_argument("--dhcp-summary", required=True)
    parser.add_argument("--completion-note", required=True)
    args = parser.parse_args()

    if len(args.packages) != len(args.package_names):
        raise SystemExit("ERROR: --package and --package-name counts must match.")

    print(f"RouterOS Netinstall — {args.device} ({args.arch}, v{args.version})")
    print("")
    print("Prerequisites:")
    print("  1. Device in Netinstall mode (hold reset 15s: flash → solid → off → release)")
    print("  2. This machine connected to device ether1 via ethernet")
    print("")

    iface = choose_interface()
    setup_script = None
    atexit.register(lambda: cleanup(iface, setup_script))

    print("")
    print(f"==> Setting up 192.168.88.2/24 on {iface}...")
    run(["sudo", "ip", "addr", "replace", "192.168.88.2/24", "dev", iface])
    run(["sudo", "ip", "link", "set", iface, "up"])

    print(f"==> Opening firewall on {iface} (temporary)...")
    run(["sudo", "iptables", "-I", "nixos-fw", "3", "-i", iface, "-j", "ACCEPT"])

    setup_script = write_setup_script(args.dhcp_clients)

    print("==> Running netinstall...")
    print(f"    Packages: {', '.join(args.package_names)}")
    print("")
    print("    Waiting for device in Netinstall mode...")
    print("")

    run(
        [
            "sudo",
            args.netinstall_cli,
            "-s",
            setup_script,
            "-i",
            iface,
            "-a",
            "192.168.88.3",
            *args.packages,
        ]
    )

    print("")
    print("========================================================")
    print(f"  Netinstall complete! ({args.device}, v{args.version})")
    print("========================================================")
    print("")
    print("  Device has been configured with:")
    print(f"    - {args.installed_summary}")
    print("    - Admin password (from clan secrets)")
    print(f"    - DHCP client on {args.dhcp_summary}")
    print("")
    print(f"  {args.completion_note}")
    print("")


if __name__ == "__main__":
    main()
