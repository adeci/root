import json
from datetime import datetime, timedelta, timezone

restic = f"/run/current-system/sw/bin/restic-{job}"
backup = f"restic-backups-{job}.service"
when_due = f"restic-{job}-when-due.service"
test_power = "/sys/module/test_power/parameters"

# What the backup keeps, with what each file holds.
kept = {
    "git/project/src/main.rs": "fn main() {}",
    "git/project/.jj/repo/store/type": "git",
    "notes/todo.md": "back up the laptops",
    ".cargo/config.toml": "[net]",
    ".local/share/PrismLauncher/instances/world/level.dat": "a world",
}
# What the exclude list leaves out, and a build folder that marks itself as a cache.
left_out = [
    ".cache/thumbnails/a.png",
    ".cargo/registry/cache/crate.crate",
    ".cargo/git/checkouts/dependency/lib.rs",
    ".rustup/toolchains/stable/bin/rustc",
    ".npm/_cacache/index-v5/entry",
    "go/pkg/mod/example.com/library/library.go",
    "git/project/node_modules/left-pad/index.js",
    "git/project/.direnv/flake-profile",
    "git/project/target/debug/project",
    ".local/share/Steam/steamapps/common/game.bin",
    ".local/share/libvirt/images/vm.qcow2",
    ".local/share/containers/storage/overlay/layer/file",
    ".local/share/Trash/files/old.txt",
    "git/pi-repos/someone--repo/README.md",
    "UniversalMac_Restore.ipsw",
]


def show(unit, prop):
    return praxis.succeed(f"systemctl show --property={prop} --value {unit}").strip()


def try_now(says):
    """Run the hourly try now and wait for it to log `says`."""
    praxis.succeed(f"systemctl start {when_due}")
    invocation = show(when_due, "InvocationID")
    praxis.wait_until_succeeds(f"journalctl _SYSTEMD_INVOCATION_ID={invocation} -o cat | grep -qF '{says}'")


def wait_for_snapshots(count):
    praxis.wait_until_succeeds(
        f"test $({list_backups} | jq length) -eq {count} && test $(systemctl show --property=ActiveState --value {backup}) = inactive"
    )


start_all()
praxis.wait_for_unit("multi-user.target")

with subtest("a home with unpushed commits, build output, caches and excluded files"):
    for path, content in kept.items():
        praxis.succeed(f"mkdir -p $(dirname {home}/{path}) && echo '{content}' > {home}/{path}")
    for path in left_out:
        praxis.succeed(f"mkdir -p $(dirname {home}/{path}) && echo '{path}' > {home}/{path}")
    praxis.succeed(
        f"printf 'Signature: 8a477f597d28d172789f06886806bc55\\n' > {home}/git/project/target/CACHEDIR.TAG",
        f"mkdir -p {home}/.ssh && echo key > {home}/.ssh/id_ed25519 && chmod 600 {home}/.ssh/id_ed25519",
        f"git -C {home}/git/project init --quiet",
        f"git -C {home}/git/project add src",
        f"git -C {home}/git/project -c user.name=Alex -c user.email=alex@example.com commit --quiet --message 'work on no remote'",
        f"chown -R alex:users {home}",
    )

with subtest("on battery the hourly try is skipped, without a failure"):
    praxis.succeed(
        "modprobe test_power",
        f"echo off > {test_power}/ac_online",
        f"echo off > {test_power}/usb_online",
        f"echo discharging > {test_power}/battery_status",
    )
    praxis.succeed(f"systemctl start {when_due}")
    assert show(when_due, "ConditionResult") == "no"
    praxis.succeed(f"echo on > {test_power}/ac_online")

with subtest("on AC power the hourly try backs up a laptop that has no repository yet"):
    try_now("Starting the backup")
    wait_for_snapshots(1)
    assert json.loads(praxis.succeed(list_backups))[0]["paths"] == [home]
    assert show(backup, "Result") == "success"

with subtest("the next try leaves a snapshot younger than 20 hours alone"):
    try_now("is less than 20 hours old")

with subtest("on a metered network the try waits"):
    connection = praxis.succeed("nmcli --get-values GENERAL.CONNECTION device show eth0").strip()
    praxis.succeed(f"nmcli connection modify '{connection}' connection.metered yes", f"nmcli connection up '{connection}'")
    praxis.wait_until_succeeds('test "$(nmcli --terse --fields METERED general)" = yes')
    try_now("the network is metered")
    praxis.succeed(f"nmcli connection modify '{connection}' connection.metered no", f"nmcli connection up '{connection}'")

with subtest("a backup stopped for sleep ends without a failure, and the next try finishes it"):
    # New data the next backup must read, read slowly enough to be caught in the middle.
    praxis.succeed(
        f"mkdir -p {home}/Videos && head --bytes=64M /dev/urandom > {home}/Videos/clip.bin",
        f"systemctl set-property --runtime {backup} CPUQuota=1%",
    )
    # A full day on, so each snapshot gets its own day and the keep rule keeps them all.
    praxis.succeed("date --set='+1 day'")
    try_now("Starting the backup")
    invocation = show(backup, "InvocationID")
    praxis.wait_until_succeeds(f"journalctl _SYSTEMD_INVOCATION_ID={invocation} -o cat | grep -q 'using parent snapshot'")
    # As logind starts it for a closed lid.
    praxis.succeed("systemctl start --job-mode=replace-irreversibly test-sleep.service")
    praxis.succeed(f"journalctl _SYSTEMD_INVOCATION_ID={invocation} -o cat | grep -q 'signal terminated received'")
    assert show(backup, "ActiveState") == "inactive"
    assert show(backup, "Result") == "success"
    praxis.succeed(f"systemctl set-property --runtime {backup} CPUQuota=")
    try_now("Starting the backup")
    wait_for_snapshots(2)

with subtest("a stale lock from a cut-off prune (sleep after the network drops) blocks no later backup"):
    # A run that holds the repository to itself, killed before it can remove its lock.
    praxis.succeed(f"systemd-run --unit=cut-off-prune --property=CPUQuota=1% {restic} prune")
    # restic writes a lock through a temporary file; only the finished one counts.
    praxis.wait_until_succeeds(f"ls {repository}/locks | grep -qxE '[0-9a-f]{{64}}'")
    praxis.succeed("systemctl kill --signal=SIGKILL cut-off-prune.service")
    # Every backup refuses the repository while that lock is there.
    praxis.fail(f"{restic} snapshots")
    praxis.succeed("date --set='+1 day'")
    try_now("Starting the backup")
    wait_for_snapshots(3)
    assert show(backup, "Result") == "success"

with subtest("a repository error makes the try start the backup and fail, rather than wait"):
    praxis.succeed(f"mv {repository}/config /tmp/config && echo damaged > {repository}/config")
    try_now("Starting the backup")
    praxis.wait_until_succeeds(f"systemctl is-failed --quiet {backup}")
    praxis.succeed(f"mv /tmp/config {repository}/config", "date --set='+1 day'")
    try_now("Starting the backup")
    wait_for_snapshots(4)

with subtest("the snapshots can be browsed in a mount"):
    praxis.succeed(f"mkdir -p /mnt/restic && systemd-run --unit=restic-mount {restic} mount /mnt/restic")
    praxis.wait_until_succeeds(f"cmp /mnt/restic/snapshots/latest{home}/notes/todo.md {home}/notes/todo.md")
    praxis.succeed("systemctl stop restic-mount.service")
    praxis.fail("mountpoint --quiet /mnt/restic")

with subtest("clan backups restore brings the whole home back with its commits, minus the excludes"):
    name = json.loads(praxis.succeed(list_backups))[-1]["name"]
    praxis.succeed(f"rm -rf {home}")
    # As clan backups restore runs it: NAME and FOLDERS set, no restore commands for home.
    praxis.succeed(f"NAME={name} FOLDERS={home} {restore}")
    for path, content in kept.items():
        assert praxis.succeed(f"cat {home}/{path}").strip() == content, path
    assert praxis.succeed(f"git -c safe.directory='*' -C {home}/git/project log --format=%s").strip() == "work on no remote"
    assert praxis.succeed(f"stat --format=%U:%a {home}/.ssh/id_ed25519").strip() == "alex:600"
    for path in left_out:
        praxis.fail(f"test -e {home}/{path}")

with subtest("snapshots of an earlier folder list thin out with the newer ones, as one history"):
    # Three notes-only snapshots ~6 months back; home daily for 13 days, weekly for 6 weeks before.
    now = datetime.fromtimestamp(int(praxis.succeed("date +%s")), timezone.utc)
    month = now.year * 12 + now.month - 7
    earlier = [datetime(month // 12, month % 12 + 1, day, 3, tzinfo=timezone.utc) for day in [1, 7, 14]]
    for time in earlier:
        praxis.succeed(f"{restic} backup --quiet --time '{time:%Y-%m-%d %H:%M:%S}' {home}/notes")
    for days in [*range(1, 14), *range(14, 56, 7)]:
        praxis.succeed(f"{restic} backup --quiet --time '{now - timedelta(days=days):%Y-%m-%d %H:%M:%S}' {home}")
    praxis.succeed(f"systemctl start {backup}")
    # Of the three, their month keeps its newest; the oldest stays while monthly slots remain.
    notes = [snapshot["date"][:10] for snapshot in json.loads(praxis.succeed(list_backups)) if snapshot["paths"] == [f"{home}/notes"]]
    assert notes == [f"{earlier[0]:%Y-%m-%d}", f"{earlier[2]:%Y-%m-%d}"], notes
