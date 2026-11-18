from ipaddress import ip_address
import json

inventory = json.loads(inventory_json)
vlans = inventory["lan"]["vlans"]
hosts = inventory["lan"]["hosts"]

# firewall.nix's zones: what each VLAN's hosts may reach through janus besides replies, "wan" being the internet.
zones = {
    "trusted": set(vlans) | {"wan"},
    "iot": {"wan"},
    "guest": {"wan"},
    "vault": {"wan"},
    "tenant": {"wan"},
    "mgmt": set(),
}
assert set(zones) == set(vlans), f"the test has zones for {sorted(zones)}, the inventory has VLANs {sorted(vlans)}"
# The VLANs firewall.nix lets ssh into janus.
admin_vlans = {"trusted", "mgmt"}
# LPD, IPP and JetDirect, which firewall.nix lets guests print with, and the printer's web page, which it doesn't.
print_ports = [515, 631, 9100]
web_port = 80

# The appliance cabled to janus's mgmt port plugs in there; every other host comes in on the trunk.
mgmt_port_host = next(
    cable["appliance"]
    for cable in inventory["lan"]["cables"]
    if cable["to"] == inventory["router"]["machine"] and cable["toPort"] == inventory["router"]["roles"]["mgmt"]
)
# A host on each VLAN without a reservation.
pool_hosts = {vlan: f"pool-{vlan}" for vlan in vlans}


def trunk(vlan):
    """The clients machine's device for a VLAN on its trunk to janus."""
    return f"trunk.{vlans[vlan]['id']}"


def netns(host):
    return f"ip netns exec {host}"


def plug_in(host, port, mac=None):
    """Gives a host a network namespace of its own and a link, with its MAC, on a port of the switch."""
    option = f"address {mac}" if mac else ""
    clients.succeed(
        f"ip link add link {port} name {host} {option} type macvlan mode bridge",
        f"ip netns add {host}",
        f"ip link set {host} netns {host}",
        f"ip -n {host} link set lo up",
        f"ip -n {host} link set {host} up",
        f"mkdir -p /etc/netns/{host}",
    )


def lease(host, client_id=None):
    """Runs the host's DHCP client, with its client id if it has one, until it is bound; returns its address."""
    option = f"-x 0x3d:{client_id.replace(':', '')}" if client_id else ""
    clients.succeed(f"{netns(host)} {busybox} udhcpc -i {host} -n -q -s {udhcpc_script} {option}")
    return json.loads(clients.succeed(f"ip -n {host} -j -4 address show dev {host}"))[0]["addr_info"][0]["local"]


def resolve(host, name, tcp=False):
    """The addresses the host's resolver, the one DHCP gave it, answers for a name, over UDP or TCP."""
    option = "+tcp" if tcp else ""
    return clients.succeed(f"{netns(host)} dig +short {option} {name}").split()


def flags(host, name):
    """The flags in the header of the host's resolver's answer for a name."""
    answer = clients.succeed(f"{netns(host)} dig +dnssec {name}")
    header = next(line for line in answer.splitlines() if line.startswith(";; flags:"))
    return header.removeprefix(";; flags:").split(";")[0].split()


# A probe that should get through may take its time on a busy machine; one that should not gets a second.
def ping(host, address, answered=True):
    """Checks that a ping from the host is answered, or that it is not."""
    if answered:
        clients.succeed(f"{netns(host)} ping -c 1 -W 5 {address}")
    else:
        clients.fail(f"{netns(host)} ping -c 1 -W 1 {address}")


def connect(host, address, port, accepted=True):
    """Checks that a TCP connection from the host is accepted, or that it is not."""
    if accepted:
        clients.succeed(f"{netns(host)} nc -z -w 5 {address} {port}")
    else:
        clients.fail(f"{netns(host)} nc -z -w 1 {address} {port}")


def listen(host, port):
    """Leaves a TCP listener running in the host's namespace."""
    clients.succeed(f"{netns(host)} nc -dlk {port} >&2 &")
    clients.wait_until_succeeds(f"{netns(host)} nc -z 127.0.0.1 {port}")


start_all()
janus.wait_for_unit("kea-dhcp4-server.service")
janus.wait_for_unit("unbound.service")
isp.wait_for_unit("bind.service")
janus.wait_until_succeeds(f"ip -4 route show default | grep -q 'via {wan_gateway} '")
wan = inventory["router"]["interfaces"]["wan"]
janus_wan = json.loads(janus.succeed(f"ip -j -4 address show dev {wan}"))[0]["addr_info"][0]["local"]

# The switch: the trunk carries every VLAN to janus's LAN port, tagged, and the mgmt link carries mgmt to its mgmt port.
clients.succeed("ip link set trunk up", "ip link set mgmt up")
for vlan, settings in vlans.items():
    clients.succeed(
        f"ip link add link trunk name {trunk(vlan)} type vlan id {settings['id']}",
        f"ip link set {trunk(vlan)} up",
    )

pool_addresses = {}
with subtest("every host gets its reserved address, by MAC or client id, and others an address from their VLAN's pool"):
    for name, host in hosts.items():
        # A host with a client id gets a random MAC, so only its client id can match its reservation.
        mac = None if host["clientId"] else host["mac"]
        plug_in(name, "mgmt" if name == mgmt_port_host else trunk(host["vlan"]), mac)
        address = lease(name, host["clientId"])
        assert address == host["ip"], f"{name} got {address}, not its reserved {host['ip']}"
    for vlan, host in pool_hosts.items():
        plug_in(host, trunk(vlan))
        address = lease(host)
        pool = vlans[vlan]["dhcpPool"]
        assert ip_address(pool["start"]) <= ip_address(address) <= ip_address(pool["end"]), f"{host} got {address}"
        pool_addresses[vlan] = address

with subtest("each VLAN's resolver from DHCP answers lan.dns names, and internet names via the ISP, by UDP and TCP"):
    for vlan, host in pool_hosts.items():
        for record in inventory["lan"]["dns"].values():
            # A name stands for a LAN host's address or a machine's tailnet address.
            expected = hosts[record["lan"]]["ip"] if record["lan"] else inventory["tailnet"][record["tailnet"]]
            assert resolve(host, record["host"]) == [expected], f"{record['host']} from {vlan}"
        assert resolve(host, internet_name) == [internet_address], f"{internet_name} from {vlan}"
        # Resolvers ask again over TCP when an answer is too big for UDP.
        assert resolve(host, internet_name, tcp=True) == [internet_address], f"{internet_name} over TCP from {vlan}"

with subtest("janus validates the internet's answers against its trust anchor"):
    assert "ad" in flags(pool_hosts["trusted"], internet_name), f"{internet_name} came back without the AD flag"

with subtest("each host's name in the LAN domain resolves to its address, unless the host keeps out of DNS"):
    for name, host in hosts.items():
        expected = [host["ip"]] if host["publishDns"] else []
        assert resolve(pool_hosts["trusted"], f"{name}.{inventory['lan']['domain']}") == expected, name

with subtest("each VLAN whose zone allows it reaches the internet, which sees only janus's address"):
    for vlan, host in pool_hosts.items():
        # The ISP has no route to the LAN, so only answers to janus's own address come back.
        ping(host, internet_address, answered="wan" in zones[vlan])

with subtest("each VLAN reaches the others exactly as its zone allows"):
    for source, host in pool_hosts.items():
        for target, address in pool_addresses.items():
            if target != source:
                ping(host, address, answered=target in zones[source])

with subtest("guests print to the printer, and reach neither its other ports nor another trusted host"):
    guest = pool_hosts["guest"]
    printer = hosts["printer"]["ip"]
    for port in print_ports + [web_port]:
        listen("printer", port)
    for port in print_ports:
        listen(pool_hosts["trusted"], port)
        connect(guest, printer, port)
        connect(guest, pool_addresses["trusted"], port, accepted=False)
    connect(guest, printer, web_port, accepted=False)

with subtest("janus answers ssh on the admin VLANs only, and the router modules' exporters on none"):
    janus.wait_for_open_port(ssh_port)
    for vlan, host in pool_hosts.items():
        connect(host, vlans[vlan]["gateway"], ssh_port, accepted=vlan in admin_vlans)
    gateway = vlans["trusted"]["gateway"]
    for port in exporter_ports:
        # They listen on every address; only the firewall keeps them to the tailnet.
        janus.wait_for_open_port(port, gateway)
        connect(pool_hosts["trusted"], gateway, port, accepted=False)

with subtest("the internet reaches neither janus's services nor the LAN, even when routed to them"):
    isp.fail(f"nc -z -w 1 {janus_wan} {ssh_port}")
    for vlan, settings in vlans.items():
        isp.succeed(f"ip route add {settings['cidr']} via {janus_wan}")
        # janus answers pings from anywhere, so the route reaches it.
        isp.succeed(f"ping -c 1 -W 5 {settings['gateway']}")
        isp.fail(f"dig +time=1 +tries=1 @{settings['gateway']} {internet_name}")
        isp.fail(f"ping -c 1 -W 1 {pool_addresses[vlan]}")
