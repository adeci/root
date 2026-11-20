from ipaddress import ip_address
import json
import re

inventory = json.loads(inventory_json)
vlans = inventory["lan"]["vlans"]
hosts = inventory["lan"]["hosts"]

# firewall.nix's zones, "wan" being the internet.
zones = {
    "trusted": (set(vlans) - {"mgmt"}) | {"wan"},
    "iot": {"wan"},
    "guest": {"wan"},
    "vault": {"wan"},
    "tenant": {"wan"},
    "mgmt": set(),
}
assert set(zones) == set(vlans), f"the test has zones for {sorted(zones)}, the inventory has VLANs {sorted(vlans)}"
# The VLANs firewall.nix lets ssh into janus.
admin_vlans = {"trusted", "mgmt"}
# Guests may print (LPD, IPP, JetDirect) but not reach the printer's web page.
print_ports = [515, 631, 9100]
web_port = 80
# An appliance's ssh port, which trusted hosts reach only through janus.
appliance_ssh_port = 22

# The appliance cabled to janus's mgmt port plugs in there; everything else on the trunk.
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
    """Give a host its own netns and a macvlan link, with its MAC, on a switch port."""
    option = f"address {mac}" if mac else ""
    clients.succeed(
        f"ip link add link {port} name {host} {option} type macvlan mode bridge",
        f"ip netns add {host}",
        f"ip link set {host} netns {host}",
        f"ip -n {host} link set lo up",
        f"ip -n {host} link set {host} up",
        f"mkdir -p /etc/netns/{host}",
    )


def own_name(host):
    """The name a host asks for its address with; a reservation's name wins over it."""
    return f"{host}-own"


# One pool host sends the client FQDN option, as some laptops do; Kea keeps the trailing dot.
fqdn_host = pool_hosts["iot"]


def lease(host, client_id=None):
    """Run udhcpc with the host's own name and client id until bound; return the address."""
    name = f"-F {own_name(host)}" if host == fqdn_host else f"-x hostname:{own_name(host)}"
    option = f"-x 0x3d:{client_id.replace(':', '')}" if client_id else ""
    clients.succeed(f"{netns(host)} {busybox} udhcpc -i {host} -n -q -s {udhcpc_script} {name} {option}")
    return json.loads(clients.succeed(f"ip -n {host} -j -4 address show dev {host}"))[0]["addr_info"][0]["local"]


def resolve(host, name, tcp=False):
    """Addresses the host's DHCP-given resolver returns for a name, over UDP or TCP."""
    option = "+tcp" if tcp else ""
    return clients.succeed(f"{netns(host)} dig +short {option} {name}").split()


def flags(host, name):
    """The flags in the header of the host's resolver's answer for a name."""
    answer = clients.succeed(f"{netns(host)} dig +dnssec {name}")
    header = next(line for line in answer.splitlines() if line.startswith(";; flags:"))
    return header.removeprefix(";; flags:").split(";")[0].split()


# Expected successes get 5 s on a busy machine; expected failures get 1 s.
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


def get_time(host, server, answered=True):
    """Checks that the host's NTP client gets the time from a server, or that the server does not answer it."""
    # chronyd needs three answers; a late one on a busy machine fails the try, so retry.
    if answered:
        clients.wait_until_succeeds(f"{netns(host)} chronyd -Q -t 10 'server {server} iburst minpoll 0'", timeout=60)
    else:
        clients.fail(f"{netns(host)} chronyd -Q -t 3 'server {server} iburst minpoll 0'")


def listen(host, port):
    """Leaves a TCP listener running in the host's namespace."""
    clients.succeed(f"{netns(host)} nc -dlk {port} >&2 &")
    clients.wait_until_succeeds(f"{netns(host)} nc -z 127.0.0.1 {port}")


def answer(host, port, reply):
    """Leaves a TCP listener in the host's namespace that answers one connection with a line."""
    clients.succeed(f"echo {reply} | {netns(host)} nc -N -l {port} >&2 &")
    clients.wait_until_succeeds(f"{netns(host)} ss -Hltn 'sport = :{port}' | grep -q .")


# The ISP comes up once janus has booted, as a modem does after a power cut.
janus.start()
clients.start()
janus.wait_for_unit("kea-dhcp4-server.service")
janus.wait_for_unit("unbound.service")
isp.start()
isp.wait_for_unit("bind.service")
janus.wait_until_succeeds(f"ip -4 route show default | grep -q 'via {wan_gateway} '")
wan = inventory["router"]["interfaces"]["wan"]
janus_wan = json.loads(janus.succeed(f"ip -j -4 address show dev {wan}"))[0]["addr_info"][0]["local"]

with subtest("the latency prober pings the internet once the ISP answers, though janus booted without it"):
    janus.wait_until_succeeds(
        f"curl -sf http://127.0.0.1:{smokeping_port}/metrics | grep -Eq '^smokeping_requests_total\\{{.*\\}} [1-9]'", timeout=60
    )

# The switch: every VLAN tagged on the trunk, mgmt untagged on the mgmt link.
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

with subtest("janus exports in-use leases with maker and name, never a guest's or tenant's own name"):
    # The monitoring agent makes the folder on a real machine.
    janus.succeed(f"mkdir -p {textfile_directory}", "systemctl start janus-dhcp-leases.service")
    exported = janus.succeed(f"cat {textfile_directory}/janus-dhcp-leases.prom")
    records = [dict(re.findall(r'(\w+)="([^"]*)"', line)) for line in exported.splitlines() if not line.startswith("#")]
    leased = {record["address"] for record in records}
    assert leased == {host["ip"] for host in hosts.values()} | set(pool_addresses.values()), f"janus exported the leases of {leased}"
    names = {record["address"]: record["hostname"] for record in records if "hostname" in record}
    expected = {host["ip"]: name for name, host in hosts.items()}
    expected.update({pool_addresses[vlan]: own_name(host) for vlan, host in pool_hosts.items() if vlan not in ("guest", "tenant")})
    assert names == expected, f"janus exported {names}, not {expected}"
    # macvlan makes up MACs for pool and client-id hosts; inventory MACs are real, except VMs'.
    for record in records:
        made_up = int(record["mac"][:2], 16) & 0x02
        known = record["maker"] not in ("private address", "unknown maker")
        assert record["maker"] == "private address" if made_up else known, f"{record['mac']} at {record['address']}: {record['maker']}"

with subtest("an appliance's replacement, with a new MAC, gets its address by its name while the old lease is live"):
    for name in inventory["appliances"]:
        replacement = f"{name}-new"
        plug_in(replacement, "mgmt" if name == mgmt_port_host else trunk(hosts[name]["vlan"]))
        client_id = hosts[name]["clientId"].replace(":", "")
        # The print script leaves the address with the appliance, so the segment never has it twice.
        address = clients.succeed(
            f"{netns(replacement)} {busybox} udhcpc -i {replacement} -n -q -s {udhcpc_print_script} -x 0x3d:{client_id}"
        ).strip()
        assert address == hosts[name]["ip"], f"{replacement} got {address}, not {name}'s {hosts[name]['ip']}"

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

with subtest("no host on trusted, reserved or from the pool, reaches a host on mgmt"):
    trusted_hosts = [name for name, host in hosts.items() if host["vlan"] == "trusted"] + [pool_hosts["trusted"]]
    mgmt_hosts = {name: host["ip"] for name, host in hosts.items() if host["vlan"] == "mgmt"}
    mgmt_hosts[pool_hosts["mgmt"]] = pool_addresses["mgmt"]
    for name in mgmt_hosts:
        listen(name, appliance_ssh_port)
    for source in trusted_hosts:
        for address in mgmt_hosts.values():
            ping(source, address, answered=False)
            connect(source, address, appliance_ssh_port, accepted=False)

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

with subtest("a trusted host reaches an appliance's API through ssh -L via janus, and not directly"):
    host = pool_hosts["trusted"]
    api = appliance_apis[mgmt_port_host]
    # janus-routeros-health polls every 30 s and would take the listener's one answer.
    janus.succeed("systemctl stop janus-routeros-health.timer janus-routeros-health.service")
    answer(mgmt_port_host, api["port"], mgmt_port_host)
    connect(host, api["address"], api["port"], accepted=False)
    ssh = f"ssh -i /root/.ssh/id_snakeoil -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -S /tmp/janus root@{vlans['trusted']['gateway']}"
    forward = f"127.0.0.1:{api['port']}:{api['address']}:{api['port']}"
    clients.succeed(f"{netns(host)} {ssh} -f -N -M -o ExitOnForwardFailure=yes -L {forward}")
    reply = clients.succeed(f"{netns(host)} nc -N -w 5 127.0.0.1 {api['port']} < /dev/null").strip()
    assert reply == mgmt_port_host, f"through janus, {api['address']}:{api['port']} answered {reply!r}"
    clients.succeed(f"{netns(host)} {ssh} -O exit")

with subtest("janus takes the time from the internet and gives it to mgmt only"):
    janus.wait_until_succeeds("chronyc waitsync 1")
    for vlan, host in pool_hosts.items():
        get_time(host, vlans[vlan]["gateway"], answered=vlan == "mgmt")

with subtest("the internet reaches neither janus's services nor the LAN, even when routed to them"):
    isp.fail(f"nc -z -w 1 {janus_wan} {ssh_port}")
    for vlan, settings in vlans.items():
        isp.succeed(f"ip route add {settings['cidr']} via {janus_wan}")
        # janus answers pings from anywhere, so the route reaches it.
        isp.succeed(f"ping -c 1 -W 5 {settings['gateway']}")
        isp.fail(f"dig +time=1 +tries=1 @{settings['gateway']} {internet_name}")
        isp.fail(f"ping -c 1 -W 1 {pool_addresses[vlan]}")
