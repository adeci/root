import argparse
import atexit
import json
import os
import shutil
import subprocess
import tempfile
import unicodedata


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


def cleanup(iface, workdir):
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
    shutil.rmtree(workdir, ignore_errors=True)


def routeros_string(value, label):
    for char in value:
        if unicodedata.category(char) == "Cc":
            raise SystemExit(f"ERROR: {label} contains control character U+{ord(char):04X}.")
    # Backslashes first, so the escapes added for quotes and dollars stay intact.
    escaped = value.replace("\\", "\\\\").replace('"', '\\"').replace("$", "\\$")
    return f'"{escaped}"'


def read_admin_password(path):
    with open(path, encoding="utf-8", newline="") as file:
        password = file.read().removesuffix("\n")
    # An empty file usually means the command that produced it failed.
    if not password:
        raise SystemExit(f"ERROR: No admin password in {path}.")
    return password


def render_setup_script(admin_user, admin_password, dhcp_clients):
    user = routeros_string(admin_user, "Admin user")
    password = routeros_string(admin_password, "Admin password")
    lines = [f"/user set {user} password={password}"]
    lines += [
        f"/ip dhcp-client add interface={interface} disabled=no" for interface in dhcp_clients
    ]
    return "".join(f"{line}\n" for line in lines)


def write_setup_script(workdir, text):
    fd, path = tempfile.mkstemp(prefix="routeros-setup-", suffix=".rsc", dir=workdir)
    with os.fdopen(fd, "w", encoding="utf-8") as script:
        script.write(text)
    return path


def main():
    parser = argparse.ArgumentParser(description="Run MikroTik RouterOS netinstall.")
    parser.add_argument("--device", required=True)
    parser.add_argument("--model", required=True)
    parser.add_argument("--arch", required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--netinstall-cli", required=True)
    parser.add_argument(
        "--package", nargs=2, metavar=("NAME", "FILE"), action="append", required=True, dest="packages"
    )
    parser.add_argument("--dhcp-client", action="append", required=True, dest="dhcp_clients")
    parser.add_argument("--admin-user", default="admin")
    parser.add_argument("--admin-password-file", required=True)
    args = parser.parse_args()

    package_names = [name for name, _ in args.packages]
    package_files = [file for _, file in args.packages]
    npk_names = [f"{name}-{args.version}-{args.arch}.npk" for name in package_names]
    installed = " + ".join(
        [f"RouterOS {args.version} ({args.arch})"] + [name for name in package_names if name != "routeros"]
    )
    dhcp_ports = " and ".join(args.dhcp_clients)
    plug_ports = " or ".join(args.dhcp_clients)

    setup_text = render_setup_script(
        args.admin_user, read_admin_password(args.admin_password_file), args.dhcp_clients
    )

    print(f"RouterOS Netinstall — {args.device}, a {args.model} ({args.arch}, v{args.version})")
    print("")
    print("Prerequisites:")
    print("  1. Device in Netinstall mode (hold reset 15s: flash → solid → off → release)")
    print("  2. This machine connected to device ether1 via ethernet")
    print("")

    iface = choose_interface()
    workdir = tempfile.mkdtemp(prefix="routeros-netinstall-", dir="/tmp")
    atexit.register(cleanup, iface, workdir)

    print("")
    print(f"==> Setting up 192.168.88.2/24 on {iface}...")
    run(["sudo", "ip", "addr", "replace", "192.168.88.2/24", "dev", iface])
    run(["sudo", "ip", "link", "set", iface, "up"])

    print(f"==> Opening firewall on {iface} (temporary)...")
    run(["sudo", "iptables", "-I", "nixos-fw", "3", "-i", iface, "-j", "ACCEPT"])

    setup_script = write_setup_script(workdir, setup_text)

    print("==> Running netinstall...")
    print(f"    Packages: {', '.join(npk_names)}")
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
            *package_files,
        ]
    )

    print("")
    print("========================================================")
    print(f"  Netinstall complete! ({args.device}, v{args.version})")
    print("========================================================")
    print("")
    print("  Device has been configured with:")
    print(f"    - {installed}")
    print(f"    - Password for {args.admin_user}")
    print(f"    - DHCP client on {dhcp_ports}")
    print("")
    print(f"  Plug {plug_ports} into the management network, then apply its configuration.")
    print("")


if __name__ == "__main__":
    main()
