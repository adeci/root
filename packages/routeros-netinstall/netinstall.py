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


def routeros_hex(value, label):
    try:
        data = bytes.fromhex(value.replace(":", ""))
    except ValueError:
        raise SystemExit(f"ERROR: {label} {value} is not hex bytes.")
    # RouterOS sends 0x... values as raw bytes.
    return f"0x{data.hex()}"


def read_admin_password(path):
    with open(path, encoding="utf-8", newline="") as file:
        password = file.read().removesuffix("\n")
    # An empty file usually means the command that produced it failed.
    if not password:
        raise SystemExit(f"ERROR: No admin password in {path}.")
    return password


def render_setup_script(admin_user, admin_password, management_port, client_id):
    user = routeros_string(admin_user, "Admin user")
    password = routeros_string(admin_password, "Admin password")
    client_id_hex = routeros_hex(client_id, "Client id")
    lines = [
        f"/user set {user} password={password}",
        f"/ip dhcp-client option add name=clientid_name code=61 value={client_id_hex}",
        # The default list, hostname,clientid, with the name in place of the MAC-based id.
        f"/ip dhcp-client add interface={management_port} dhcp-options=hostname,clientid_name disabled=no",
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
    parser.add_argument("--management-port", required=True)
    parser.add_argument("--client-id", required=True)
    parser.add_argument("--admin-user", default="admin")
    parser.add_argument("--admin-password-file", required=True)
    args = parser.parse_args()

    package_names = [name for name, _ in args.packages]
    package_files = [file for _, file in args.packages]
    npk_names = [f"{name}-{args.version}-{args.arch}.npk" for name in package_names]
    installed = " + ".join(
        [f"RouterOS {args.version} ({args.arch})"] + [name for name in package_names if name != "routeros"]
    )

    setup_text = render_setup_script(
        args.admin_user,
        read_admin_password(args.admin_password_file),
        args.management_port,
        args.client_id,
    )

    print(f"RouterOS Netinstall: {args.device}, a {args.model} ({args.arch}, v{args.version})")
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
    print(f"    - DHCP client on {args.management_port}, sending its name as client id {args.client_id}")
    print("")
    print("  Plug ether1 back into its cable; the rebuild goes on from here.")
    print("")


if __name__ == "__main__":
    main()
