import shlex


def ssh(seat):
    return (
        "timeout 60 ssh -o StrictHostKeyChecking=yes -o ConnectTimeout=5"
        " -o ServerAliveInterval=5 -o ServerAliveCountMax=3"
        f" -i /root/.ssh/id_snakeoil root@{ips[seat]}"
    )

def on_seat(seat, command):
    return janus.wait_until_succeeds(f"{ssh(seat)} {shlex.quote(command)}", timeout=180)

def bound(seat):
    return leviathan.succeed(f"basename $(readlink /sys/bus/pci/devices/{devices[seat]}/driver)").strip()

def wait_bound(seat, driver):
    # The GPU comes back after the VM unit stops, as its passthrough unit stops.
    leviathan.wait_until_succeeds(
        f"test \"$(basename $(readlink /sys/bus/pci/devices/{devices[seat]}/driver))\" = {driver}", timeout=60
    )

def used(seat):
    return int(leviathan.succeed(f"du -B1M /var/lib/microvms/{seat}/home.img | cut -f1"))

start_all()
janus.wait_for_unit("dnsmasq.service")
for seat in seats:
    janus.succeed(f"echo \"{ips[seat]} $(cat /root/secrets/{seat}.pub)\" >> /root/.ssh/known_hosts")
leviathan.wait_for_unit("fake-gpu-holder.service")
for seat in seats:
    assert bound(seat) == "e1000e", bound(seat)

with subtest("the host bridges the VLAN without an address on it"):
    leviathan.wait_until_succeeds("ip -d link show eth1 | grep -q 'master br-tenant'")
    leviathan.fail("ip -4 -o addr show dev br-tenant | grep -q inet")
    leviathan.fail("ip -4 -o addr show dev eth1 | grep -q inet")

with subtest("seats boot with their GPU, address, and SSH host key"):
    leviathan.succeed("systemctl start microvm@scylla microvm@charybdis")
    for seat in seats:
        assert bound(seat) == "vfio-pci", bound(seat)
        janus.wait_until_succeeds(f"{ssh(seat)} true", timeout=600)
        on_seat(seat, "grep -qx 0x10d3 /sys/bus/pci/devices/*/device")
        # What Moonshine runs for a Moonlight stream.
        janus.succeed(
            f"{ssh(seat)} systemd-run --machine=gamer@.host --user --slice=moonshine"
            " --unit=moonshine-session /run/current-system/sw/bin/sleep infinity"
        )

with subtest("seats reach the gateway but not each other"):
    on_seat("scylla", f"ping -c1 -W2 {tenant_gateway}")
    janus.fail(f"{ssh('scylla')} ping -c1 -W2 {ips['charybdis']}")
    janus.fail(f"{ssh('charybdis')} ping -c1 -W2 {ips['scylla']}")

with subtest("each seat gets its secrets, root-only and read-only"):
    for seat in seats:
        assert on_seat(seat, "ls /run/seed/secrets").split() == ["ssh-host-key", "tailscale-gaming"]
        on_seat(seat, "grep -qx tskey-fixture /run/seed/secrets/tailscale-gaming")
        assert on_seat(seat, "stat -c '%u %g %a' /run/seed/secrets/tailscale-gaming").strip() == "0 0 400"
        on_seat(seat, "findmnt -n -o OPTIONS /run/seed | grep -qw ro")

with subtest("homes are per seat, sized per seat, and freed space returns to the host"):
    for seat, size in [("scylla", 256), ("charybdis", 128)]:
        home = int(on_seat(seat, "df --output=size -BG /home | tail -1").strip().rstrip("G"))
        assert size - 6 <= home <= size, (seat, home)
    on_seat("scylla", "touch /home/gamer/game")
    janus.fail(f"{ssh('charybdis')} test -e /home/gamer/game")
    before = used("scylla")
    on_seat("scylla", "dd if=/dev/urandom of=/home/gamer/big bs=1M count=512 status=none && sync")
    assert used("scylla") >= before + 500, (before, used("scylla"))
    on_seat("scylla", "rm /home/gamer/big && sync && fstrim /home")
    assert used("scylla") <= before + 64, (before, used("scylla"))

with subtest("stopping a seat returns only its GPU and seed"):
    leviathan.succeed("systemctl stop microvm@charybdis")
    wait_bound("charybdis", "e1000e")
    assert bound("scylla") == "vfio-pci", bound("scylla")
    leviathan.wait_until_fails("test -e /run/microvm-seeds/charybdis.img", timeout=30)
    leviathan.succeed("test -e /run/microvm-seeds/scylla.img")

with subtest("a seat whose VM unit cannot run anything still returns its GPU"):
    # As on leviathan, where a NUMA policy for a memoryless node failed every
    # command in the unit, its own stop commands included.
    leviathan.succeed(
        "mkdir -p /run/systemd/system/microvm@charybdis.service.d"
        " && printf '[Service]\\nNUMAPolicy=preferred\\nNUMAMask=7\\n'"
        " > /run/systemd/system/microvm@charybdis.service.d/zz-fail.conf"
        " && systemctl daemon-reload"
    )
    leviathan.fail("systemctl start microvm@charybdis")
    wait_bound("charybdis", "e1000e")
    leviathan.succeed(
        "rm -r /run/systemd/system/microvm@charybdis.service.d"
        " && systemctl daemon-reload && systemctl reset-failed microvm@charybdis"
    )

with subtest("an idle seat powers off cleanly and returns its GPU"):
    janus.succeed(f"{ssh('scylla')} systemctl --machine=gamer@.host --user stop moonshine-session")
    leviathan.wait_until_succeeds(
        "systemctl show -P ActiveState microvm@scylla | grep -qxE 'inactive|failed'", timeout=300
    )
    assert leviathan.succeed("systemctl show -P Result microvm@scylla").strip() == "success"
    wait_bound("scylla", "e1000e")
    leviathan.wait_until_fails("test -e /run/microvm-seeds/scylla.img", timeout=30)

with subtest("GPU holders only started with every GPU settled"):
    saw = [line.split() for line in leviathan.succeed("cat /run/holder-saw").splitlines() if line.strip()]
    assert all(driver in ("e1000e", "vfio-pci") for state in saw for driver in state), saw
    assert saw[-1] == ["e1000e", "e1000e"], saw
    leviathan.succeed("systemctl is-active fake-gpu-holder")

with subtest("a magic packet from the trusted LAN starts its seat, one from the tenant VLAN does not"):
    janus.succeed(f"wakeonlan -i {tenant_broadcast} {macs['charybdis']}")
    janus.succeed(f"wakeonlan -i 192.168.2.255 {macs['scylla']}")
    leviathan.wait_for_unit("microvm@scylla.service", timeout=180)
    leviathan.fail("systemctl is-active microvm@charybdis")
