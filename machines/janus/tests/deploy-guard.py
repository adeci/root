import datetime as dt
import json

inventory = json.loads(inventory_json)
# The test driver has globals of its own named vlans and hosts.
trusted = inventory["lan"]["vlans"]["trusted"]
mgmt_bridge = inventory["lan"]["vlans"]["mgmt"]["interface"]
name = f"nexus.{inventory['lan']['domain']}"
nexus_address = inventory["lan"]["hosts"]["nexus"]["ip"]
gateway = trusted["gateway"]
# -n: ssh must leave alone its stdin, which is the test driver's shell.
ssh = "ssh -n -i /root/.ssh/id_snakeoil -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o ConnectTimeout=5"


def netns(host):
    return f"ip netns exec {host}"


def plug_in(host):
    """Give a host its own netns and a link on the trusted VLAN."""
    clients.succeed(
        f"ip link add link trunk.{trusted['id']} name {host} type macvlan mode bridge",
        f"ip netns add {host}",
        f"ip link set {host} netns {host}",
        f"ip -n {host} link set lo up",
        f"ip -n {host} link set {host} up",
        f"mkdir -p /etc/netns/{host}",
    )


def lease(host, attempts=3):
    """Run udhcpc until bound or it gives up."""
    return f"{netns(host)} {busybox} udhcpc -i {host} -n -q -t {attempts} -s {udhcpc_script}"


def resolve(host):
    return f"{netns(host)} dig +short +time=2 +tries=1 {name}"


def new_connection(command):
    """A command on janus over a new connection, as clan's confirmation opens."""
    return f"{netns('deployer')} {ssh} -o ControlPath=none root@{gateway} {command}"


def held_connection(command):
    """A command on janus over the connection the deploy holds open through its switch."""
    return f"{netns('deployer')} {ssh} -o ControlPath=/tmp/deploy root@{gateway} {command}"


def confirm(system):
    """clan's confirmation of a switch to the system."""
    return new_connection(f"deploy-guard-confirm {system}")


def clan_switch(system):
    """Switch janus with the patched clan-cli's activation and confirmation, over its own connection."""
    return f"{netns('deployer')} env PYTHONPATH={clan_lib} {clan_python} {clan_switch_script} {gateway} {system} < /dev/null 2>&1"


def specialisation(system):
    return janus.succeed(f"readlink -f /run/booted-system/specialisation/{system}").strip()


def now():
    return int(janus.succeed("date +%s"))


def deploy(system):
    """Switch as clan does: profile, boot default, then the live switch in a transient unit."""
    janus.succeed(f"nix-env --profile /nix/var/nix/profiles/system --set {system}")
    janus.succeed(f"{system}/bin/switch-to-configuration boot")
    status, output = janus.execute(
        f"systemd-run --pipe --wait --quiet --collect --service-type=exec {system}/bin/switch-to-configuration switch 2>&1"
    )
    print(output)
    return status, output


def runs(system):
    """Check that janus runs the system and boots it next (GRUB's first entry)."""
    janus.succeed(f'test "$(readlink -f /run/current-system)" = {system}')
    janus.succeed(f'test "$(readlink -f /nix/var/nix/profiles/system)" = {system}')
    janus.succeed(f"grep -m 1 -o 'init=[^ ]*' /boot/grub/grub.cfg | grep -qx 'init={system}/init'")


def wait_for_revert(since):
    """Wait for a revert after `since` by janus's clock; one just before may share its second."""
    janus.wait_until_succeeds(
        f"test \"$(sed -n 's/^deploy_guard_revert_timestamp_seconds //p' {metrics_file})\" -gt {since}",
        timeout=dt.timedelta(seconds=window + 120),
    )
    janus.wait_until_fails("systemctl is-active deploy-guard-revert.service")
    # Nothing armed a revert of the revert.
    janus.fail("systemctl is-active deploy-guard-revert.timer")
    janus.fail("test -e /run/deploy-guard")


start_all()
janus.wait_for_unit("kea-dhcp4-server.service")
janus.wait_for_unit("unbound.service")
janus.wait_for_unit("sshd.service")
original = janus.succeed("readlink -f /run/current-system").strip()
harmless = specialisation("harmless")

clients.succeed(
    "ip link set trunk up",
    "ip link set mgmt up",
    f"ip link add link trunk name trunk.{trusted['id']} type vlan id {trusted['id']}",
    f"ip link set trunk.{trusted['id']} up",
)
plug_in("deployer")
clients.succeed(lease("deployer"))
clients.succeed(f"{netns('deployer')} {ssh} -o ControlMaster=yes -o ControlPath=/tmp/deploy -o ControlPersist=1h -fN root@{gateway}")

with subtest("with no switch waiting, a confirmation has nothing to do"):
    assert "No switch is waiting" in clients.succeed(confirm(original))

with subtest("the lease check leaves janus's mgmt bridge as it found it"):
    mac = janus.succeed(f"cat /sys/class/net/{mgmt_bridge}/address")
    janus.succeed(lease_check)
    assert janus.succeed(f"cat /sys/class/net/{mgmt_bridge}/address") == mac, f"{mgmt_bridge} changed its address"
    janus.fail("ip link show deploy-guard")
    janus.fail("ip netns list | grep -q deploy-guard")

with subtest("a switch confirmed over a new connection stays, even with a check that already failed"):
    output = clients.succeed(clan_switch(harmless))
    assert "upstream already fails" in output, output
    assert "goes back to its previous system at" in output, output
    assert "upstream: failed before the switch too" in output, output
    assert "Confirmed" in output, output
    janus.sleep(window + 15)
    runs(harmless)
    janus.fail(f"test -e {metrics_file}")

with subtest("a switch that locks out ssh reverts after its window, though the deploy's connection lasts"):
    since = now()
    closes_ssh = specialisation("closesSsh")
    # clan's own connection outlives the switch; only a new one shows the lockout.
    output = clients.fail(clan_switch(closes_ssh))
    assert "did not confirm this switch over a new connection, so it goes back" in output, output
    clients.succeed(held_connection("true"))
    janus.succeed(f"nix-store --query --roots {harmless} | grep -q /run/deploy-guard/previous")
    assert janus.succeed("systemctl show --property=AccuracyUSec --value deploy-guard-revert.timer").strip() == "1s"
    wait_for_revert(since)
    runs(harmless)
    # A confirmation that only gets through once janus is back does not count.
    assert "no longer runs" in clients.fail(confirm(closes_ssh))
    # The next deploy, finding janus already on its system, clears the revert report.
    assert "No switch is waiting" in clients.succeed(confirm(harmless))
    janus.fail(f"test -e {metrics_file}")

with subtest("a revert the previous system refuses leaves janus on the new system, its unit failed"):
    deploy(original)
    janus.succeed("touch /run/deploy-guard-test-refuse")
    janus.wait_until_succeeds(
        "systemctl is-failed --quiet deploy-guard-revert.service",
        timeout=dt.timedelta(seconds=window + 120),
    )
    runs(original)
    janus.fail(f"test -e {metrics_file}")
    # The next switch arms anew from the system janus runs, and clears the failed unit.
    janus.succeed("rm /run/deploy-guard-test-refuse")
    deploy(harmless)
    assert "Confirmed" in clients.succeed(confirm(harmless))
    janus.fail("systemctl is-failed --quiet deploy-guard-revert.service")
    runs(harmless)

with subtest("a switch that breaks DHCP goes back though Kea keeps running, and hosts get leases again"):
    since = now()
    deploy(specialisation("breaksDhcp"))
    janus.succeed("systemctl is-active kea-dhcp4-server.service")
    plug_in("dhcp")
    clients.fail(lease("dhcp", attempts=2))
    confirmation = clients.fail(confirm(specialisation("breaksDhcp")))
    assert "dhcp: passes" in confirmation and "lease: fails" in confirmation, confirmation
    wait_for_revert(since)
    runs(harmless)
    clients.succeed(lease("dhcp"))
    assert clients.succeed(resolve("dhcp")).split() == [nexus_address]

with subtest("a switch that breaks DNS on the LAN goes back though Unbound keeps running, and hosts resolve names again"):
    since = now()
    deploy(specialisation("breaksDns"))
    janus.succeed("systemctl is-active unbound.service")
    plug_in("dns")
    clients.succeed(lease("dns"))
    clients.fail(resolve("dns"))
    confirmation = clients.fail(confirm(specialisation("breaksDns")))
    assert "dns: passes" in confirmation and "lease: fails" in confirmation, confirmation
    wait_for_revert(since)
    runs(harmless)
    assert clients.succeed(resolve("dns")).split() == [nexus_address]

with subtest("a switch killed after it stopped units comes back with them"):
    since = now()
    status, _ = deploy(specialisation("diesMidSwitch"))
    assert status != 0, "the switch was not killed"
    janus.fail("systemctl is-active kea-dhcp4-server.service")
    wait_for_revert(since)
    runs(harmless)
    janus.wait_for_unit("kea-dhcp4-server.service")
    plug_in("killed")
    clients.succeed(lease("killed"))

with subtest("a switch that outlasts its window goes back once it has finished"):
    since = now()
    outlasts_window = specialisation("outlastsWindow")
    deploy(outlasts_window)
    assert "Not confirmed" in clients.fail(confirm(outlasts_window))
    wait_for_revert(since)
    runs(harmless)

with subtest("a second switch before the confirmation gets a fresh window, back to the last confirmed system"):
    since = now()
    deploy(specialisation("breaksDns"))
    janus.sleep(25)
    deploy(closes_ssh)
    # Past the first switch's window, inside the second's.
    janus.sleep(window - 15)
    janus.succeed(f'test "$(readlink -f /run/current-system)" = {closes_ssh}')
    wait_for_revert(since)
    runs(harmless)
