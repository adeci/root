import socket
import subprocess
import sys

port = int(sys.argv[1])
vm_by_mac = {}
for pair in sys.argv[2:]:
    mac, name = pair.split("=")
    vm_by_mac[mac.lower()] = name


def target(packet):
    start = packet.find(b"\xff" * 6)
    mac = packet[start + 6:start + 12]
    if start >= 0 and packet[start + 6:start + 102] == mac * 16:
        return vm_by_mac.get(mac.hex(":"))


listener = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
listener.bind(("", port))
while True:
    name = target(listener.recv(1024))
    if name:
        subprocess.run(["systemctl", "start", "--no-block", f"microvm@{name}"])
