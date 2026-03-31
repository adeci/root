"""Bootstrap a factory-fresh RouterOS device for Terraform management.

Expects: factory-reset RouterOS device plugged into this machine.
Does: set password, clear ALL default config, add DHCP client on ether1.
After: plug ether1 into network, run routeros-deploy.
"""

import json
import subprocess
import sys
import time
import urllib.error
import urllib.request
from base64 import b64encode
from contextlib import contextmanager

API = "http://192.168.88.1/rest"
BOOTSTRAP_IP = "192.168.88.2/24"


class ApiError(Exception):
    pass


def api(path, method="GET", data=None, auth=None, timeout=5, lenient=False):
    """Make a RouterOS REST API call.

    Returns parsed JSON on success, None on empty response.
    Raises ApiError on failure unless lenient=True (for best-effort calls
    where the device may have already dropped its IP).
    """
    url = f"{API}/{path.lstrip('/')}"
    headers = {}

    if data is not None:
        headers["Content-Type"] = "application/json"

    user, password = auth if auth else ("admin", "")
    encoded = b64encode(f"{user}:{password}".encode()).decode()
    headers["Authorization"] = f"Basic {encoded}"

    body = json.dumps(data).encode() if data is not None else None
    req = urllib.request.Request(url, data=body, headers=headers, method=method)

    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            content = resp.read()
            return json.loads(content) if content else None
    except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError, OSError) as e:
        if lenient:
            return None
        raise ApiError(f"API call failed: {method} {path} — {e}") from e


def get_ethernet_interfaces():
    """List physical ethernet interfaces with their link state."""
    result = subprocess.run(
        ["ip", "-j", "link", "show"],
        capture_output=True, text=True, check=True,
    )
    interfaces = []
    for iface in json.loads(result.stdout):
        name = iface["ifname"]
        state = iface.get("operstate", "UNKNOWN")
        if name.startswith(("en", "eth")):
            interfaces.append((name, state))
    return interfaces


def pick_interface():
    """Interactive interface picker. Returns selected interface name."""
    interfaces = get_ethernet_interfaces()
    if not interfaces:
        print("ERROR: No ethernet interfaces found.")
        sys.exit(1)

    print("Select the interface connected to the RouterOS device:\n")
    for i, (name, state) in enumerate(interfaces):
        print(f"  {i + 1}) {name:<20} [{state}]")

    print()
    try:
        choice = int(input("Enter number: ")) - 1
        if 0 <= choice < len(interfaces):
            return interfaces[choice][0]
    except (ValueError, IndexError):
        pass

    print("ERROR: Invalid selection.")
    sys.exit(1)


def run(*cmd):
    """Run a command, suppressing output."""
    subprocess.run(cmd, capture_output=True)


@contextmanager
def temporary_ip(interface):
    """Add 192.168.88.2/24 to an interface, clean up on exit."""
    print(f"\n==> Temporarily assigning {BOOTSTRAP_IP} to {interface} (requires sudo)")
    run("sudo", "nmcli", "device", "set", interface, "managed", "no")
    run("sudo", "ip", "addr", "add", BOOTSTRAP_IP, "dev", interface)
    run("sudo", "ip", "link", "set", interface, "up")
    time.sleep(2)

    try:
        yield
    finally:
        print(f"\n==> Cleaning up: removing {BOOTSTRAP_IP} from {interface}")
        run("sudo", "ip", "addr", "del", BOOTSTRAP_IP, "dev", interface)
        run("sudo", "nmcli", "device", "set", interface, "managed", "yes")


def get_password():
    """Read the RouterOS password from clan secrets."""
    result = subprocess.run(
        ["clan", "secrets", "get", "routeros-password"],
        capture_output=True, text=True, check=True,
    )
    return result.stdout.strip()


def main():
    ros_iface = sys.argv[1] if len(sys.argv) > 1 else "ether1"
    interface = pick_interface()

    with temporary_ip(interface):
        # ── Connect ──────────────────────────────────────────────────
        print("==> Checking for RouterOS device at 192.168.88.1...")
        try:
            identity = api("system/identity")
        except ApiError:
            identity = None

        if identity is None:
            print(
                "\nERROR: Cannot reach a RouterOS device at 192.168.88.1\n"
                "\nChecklist:\n"
                "  - Is the device powered on and fully booted?\n"
                "  - Was it factory-reset? (hold reset until USR LED flashes, then release)\n"
                f"  - Is an ethernet cable connecting {interface} to a port on the device?"
            )
            sys.exit(1)

        print(f"    Found: {identity.get('name', 'MikroTik')}")

        # ── Set password ─────────────────────────────────────────────
        print("==> Setting admin password from clan secrets...")
        password = get_password()
        api("user/admin", method="PATCH", data={"password": password})
        print("    Password set.")

        auth = ("admin", password)

        # ── Clear default config ─────────────────────────────────────
        print(f"==> Clearing default config and adding DHCP client on {ros_iface}...")

        script = "\n".join([
            "/ip firewall filter remove [find]",
            "/ip firewall nat remove [find]",
            "/interface list member remove [find]",
            "/ip dhcp-server remove [find]",
            "/ip pool remove [find]",
            "/ip address remove [find]",
            "/interface bridge port remove [find]",
            "/interface bridge remove [find]",
            f"/ip dhcp-client add interface={ros_iface} disabled=no",
        ])

        # Remove previous bootstrap script if it exists (best-effort)
        api("system/script/remove", method="POST",
            data={"numbers": "terraform-bootstrap"}, auth=auth, lenient=True)

        # Upload the cleanup script
        api("system/script/add", method="POST",
            data={"name": "terraform-bootstrap", "source": script}, auth=auth)

        # Run it — device drops its IP here, timeout is expected
        api("system/script/run", method="POST",
            data={"number": "terraform-bootstrap"}, auth=auth, timeout=10, lenient=True)

        # Best-effort cleanup (device likely unreachable)
        api("system/script/remove", method="POST",
            data={"numbers": "terraform-bootstrap"}, auth=auth, timeout=3, lenient=True)

        print("    Done.")

    print(f"""
========================================================
  Bootstrap complete!
========================================================

  The device has been configured with:
    - Admin password (from clan secrets)
    - Default config cleared (bridge, firewall, IPs)
    - DHCP client on {ros_iface}

""")


if __name__ == "__main__":
    main()
