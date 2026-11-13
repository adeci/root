"""First install and remaining System Settings steps."""

import json
import shlex
import tempfile
import time
from dataclasses import dataclass
from functools import partial
from pathlib import Path
from typing import NoReturn

from . import Error, ui
from .mac import NIX_BIN, CommandError, Mac, connect, run, secrets_tarball

SETUP_JSON = "/etc/mac-setup.json"
# Root reads the privacy database only from a session with Full Disk Access.
FDA_CHECK = "/usr/bin/sqlite3 '/Library/Application Support/com.apple.TCC/TCC.db' 'select 1' >/dev/null 2>&1"
SHARING_SETTINGS = "x-apple.systempreferences:com.apple.Sharing-Settings.extension"


def flake_root() -> Path:
    argv = ["git", "rev-parse", "--show-toplevel"]
    result = run(argv, capture=True, quiet=True, check=False)
    if result.returncode != 0:
        msg = "not in a git checkout: run this from the flake's repository"
        raise Error(msg)
    return Path(result.stdout.strip())


def nix_eval(machine: str, attr: str, *flags: str) -> str:
    """`nix eval` of the flake, saying so when it failed because there is no such machine."""
    argv = ["nix", "eval", *flags, f".#{attr}"]
    try:
        return run(argv, capture=True, quiet=True).stdout
    except CommandError:
        names = ["--json", "--apply", "builtins.attrNames", ".#darwinConfigurations"]
        out = run(["nix", "eval", *names], capture=True, quiet=True).stdout
        machines = [str(name) for name in json.loads(out)]
        if machine not in machines:
            known = ", ".join(machines) or "none"
            msg = f"no darwinConfigurations.{machine} in this flake (darwin machines: {known})"
            raise Error(msg) from None
        raise


def option(machine: str, name: str) -> str:
    return nix_eval(machine, f"darwinConfigurations.{machine}.config.{name}", "--raw")


def deploy_host(machine: str) -> str:
    """The machine's inventory deploy.targetHost, without its user."""
    attr = f"clan.inventory.machines.{machine}.deploy.targetHost"
    try:
        target = nix_eval(machine, attr, "--raw")
    except CommandError:
        msg = f"no deploy.targetHost for {machine} in the inventory: pass its address"
        raise Error(msg) from None
    return target.rpartition("@")[2]


@dataclass(frozen=True)
class Step:
    name: str
    url: str
    instructions: str
    check: str | None
    restart: tuple[str, ...]


@dataclass(frozen=True)
class Setup:
    user: str
    uid: int
    steps: tuple[Step, ...]


_KINDS = {dict: "an object", list: "a list", str: "a string", int: "a number"}


def _reject(field: str, expected: str, value: object) -> NoReturn:
    msg = f"{SETUP_JSON}: {field} should be {expected}, not {json.dumps(value)}"
    raise Error(msg)


def _expect[T](value: object, kind: type[T], field: str) -> T:
    # Python counts a bool as an int; no field here is one.
    if isinstance(value, bool) or not isinstance(value, kind):
        _reject(field, _KINDS[kind], value)
    return value


def _parse_step(value: object, field: str) -> Step:
    step = _expect(value, dict, field)
    check = step.get("check")
    if check is not None and not isinstance(check, str):
        _reject(f"{field}.check", "a string or null", check)
    restart = _expect(step.get("restart"), list, f"{field}.restart")
    if not all(isinstance(service, str) for service in restart):
        _reject(f"{field}.restart", "a list of strings", restart)
    return Step(
        name=_expect(step.get("name"), str, f"{field}.name"),
        url=_expect(step.get("url"), str, f"{field}.url"),
        instructions=_expect(step.get("instructions"), str, f"{field}.instructions"),
        check=check,
        restart=tuple(restart),
    )


def parse_setup(text: str) -> Setup:
    try:
        data = json.loads(text)
    except json.JSONDecodeError as e:
        msg = f"{SETUP_JSON}: {e}"
        raise Error(msg) from None
    setup = _expect(data, dict, "the top level")
    steps = _expect(setup.get("steps"), list, "steps")
    return Setup(
        user=_expect(setup.get("user"), str, "user"),
        uid=_expect(setup.get("uid"), int, "uid"),
        steps=tuple(_parse_step(step, f"steps[{i}]") for i, step in enumerate(steps)),
    )


def deployed_setup(mac: Mac) -> Setup | None:
    if not mac.succeeds(f"test -e {SETUP_JSON}"):
        return None
    return parse_setup(mac.read(f"cat {SETUP_JSON}"))


def declared_setup(machine: str) -> Setup | None:
    attr = f"darwinConfigurations.{machine}.config.environment.etc"
    apply = 'etc: etc."mac-setup.json".text or null'
    text = json.loads(nix_eval(machine, attr, "--json", "--apply", apply))
    return parse_setup(text) if isinstance(text, str) else None


def restart(mac: Mac, setup: Setup, step: Step) -> None:
    # Apps only appear in a Privacy list once they've run, and need a restart to pick up a grant.
    for service in step.restart:
        # launchctl spells a service in the user's session gui/<uid>/<label>.
        target = service
        if service.startswith("gui/"):
            target = f"gui/{setup.uid}/{service.removeprefix('gui/')}"
        # Backgrounded: a launch can sit behind a dialog.
        command = f"launchctl kickstart -k {shlex.quote(target)} >/dev/null 2>&1 &"
        mac.change(command, check=False)


def take_through(mac: Mac, setup: Setup, step: Step) -> bool:
    """Open the step's page as the user and wait until it's done; False when they skipped it."""
    ui.todo(f"{step.name}: {step.instructions}")
    restart(mac, setup, step)
    mac.open_as(setup.uid, setup.user, step.url)
    if mac.dry_run:
        ui.would("wait for it, then restart its services again")
        return True
    if step.check is None:
        ui.wait_for_enter("Enter when done")
        finished = True
    else:
        ui.detail("waiting for it (Enter skips)")
        finished = ui.until(partial(mac.succeeds, step.check))
    restart(mac, setup, step)
    if finished:
        ui.done(step.name)
    else:
        ui.warn(f"{step.name}: skipped; its check still fails")
    return finished


def system_settings(mac: Mac, setup: Setup | None) -> list[Step]:
    """Take the person through each step that isn't done; returns the ones they skipped."""
    ui.section("System Settings")
    if setup is None or not setup.steps:
        ui.line("nothing declared")
        return []
    skipped = []
    for step in setup.steps:
        if step.check is not None and mac.succeeds(step.check):
            ui.done(step.name)
        elif not take_through(mac, setup, step):
            skipped.append(step)
    return skipped


def remind(machine: str, skipped: list[Step]) -> None:
    if skipped:
        names = ", ".join(step.name for step in skipped)
        ui.line(f"- System Settings: {names} (mac-install settings {machine})")


def full_disk_access(mac: Mac, uid: int, user: str) -> None:
    ui.section("Full Disk Access for remote users")
    # Activation writes files macOS guards even from root, like /etc/pam.d; SSH sessions only get past that with this on.
    # New connections each time: a session opened before the toggle keeps running without it.
    if mac.succeeds(FDA_CHECK, fresh=True):
        ui.done("on")
        return
    ui.todo('Remote Login (i) > turn on "Allow full disk access for remote users"')
    mac.open_as(uid, user, SHARING_SETTINGS, fresh=True)
    if mac.dry_run:
        ui.would("wait up to 5 minutes for it")
        ui.detail("until then, steps checked against the privacy database look undone")
        return
    ui.detail("waiting up to 5 minutes")
    deadline = time.monotonic() + 5 * 60
    while not mac.succeeds(FDA_CHECK, fresh=True):
        if time.monotonic() >= deadline:
            msg = "still off after 5 minutes; turn it on and run this again"
            raise Error(msg)
        time.sleep(2)
    mac.disconnect()
    ui.done("on")


def filevault(mac: Mac) -> None:
    ui.section("FileVault")
    # A warning, not a stop: turning it on is a separate decision, and it can wait.
    if mac.succeeds("fdesetup isactive"):
        ui.done("on")
    else:
        ui.warn("off: System Settings > Privacy & Security > FileVault")


def upload_secrets(mac: Mac, machine: str) -> None:
    ui.section("Secrets")
    upload_dir = option(machine, "clan.core.vars.sops.secretUploadDirectory")
    quoted = shlex.quote(upload_dir)
    unpack = f"install -d -m 700 {quoted} && tar -C {quoted} -xpf -"
    if mac.dry_run:
        argv = ["clan", "vars", "check", machine]
        vars_check = run(argv, capture=True, quiet=True, check=False)
        if vars_check.returncode == 0:
            ui.done("vars up to date")
        else:
            ui.todo("vars to generate")
            for line in vars_check.stdout.splitlines():
                ui.detail(line)
            ui.would(f"run: clan vars generate {machine}")
        ui.would(f"run: clan vars upload {machine} --directory <temporary directory>")
        mac.change(unpack)
        return
    # Prompted vars ask on the terminal.
    run(["clan", "vars", "generate", machine], interactive=True)
    with tempfile.TemporaryDirectory(prefix="mac-install-secrets-") as tmp:
        run(["clan", "vars", "upload", machine, "--directory", tmp])
        run(mac.ssh(unpack), stdin=secrets_tarball(Path(tmp)))
    ui.line(f"uploaded to {upload_dir}")


def copy_flake(mac: Mac) -> str:
    ui.section("Copying the flake")
    # The Mac trusts only cache.nixos.org's key, so inputs this machine got from other caches need --no-check-sigs.
    store = f"ssh-ng://{mac.target}?remote-program={NIX_BIN}/nix-daemon"
    archive = ["nix", "flake", "archive", "--json"]
    if mac.dry_run:
        out = run([*archive, "--dry-run", "."], capture=True, quiet=True).stdout
        path = str(json.loads(out)["path"])
        ui.would(f"copy {path} and its inputs to {store}")
        return path
    argv = [*archive, "--no-check-sigs", "--to", store, "."]
    env = {"NIX_SSHOPTS": " ".join(mac.shared)}
    path = str(json.loads(run(argv, env=env, capture=True).stdout)["path"])
    ui.line(path)
    return path


def first_switch(mac: Mac, flake_path: str, machine: str) -> None:
    ui.section("First switch (built on the Mac)")
    if mac.dry_run:
        current = mac.read("readlink /run/current-system || true").strip()
        ui.line(f"now running {current}" if current else "no nix-darwin system yet")
    # What `darwin-rebuild switch` does: set the system profile, then activate. The installer's nix.conf would block nix-darwin's.
    if mac.succeeds("[ -e /etc/nix/nix.conf ] && [ ! -L /etc/nix/nix.conf ]"):
        mac.change("mv /etc/nix/nix.conf /etc/nix/nix.conf.before-nix-darwin")
    attr = shlex.quote(f"{flake_path}#darwinConfigurations.{machine}.system")
    build = f"{NIX_BIN}/nix --extra-experimental-features 'nix-command flakes' build --no-link --print-out-paths {attr}"
    if mac.dry_run:
        ui.would(f"run on the Mac: {build}")
        system = "<system>"
    else:
        # Its progress shows; its output is the system.
        system = run(mac.ssh(build), capture=True).stdout.strip()
    profile = "/nix/var/nix/profiles/system"
    mac.change(f"{NIX_BIN}/nix-env -p {profile} --set {shlex.quote(system)}")
    mac.change(f"{shlex.quote(system)}/activate")


def install(machine: str, address: str, *, dry_run: bool) -> None:
    ui.section(machine)
    user = option(machine, "system.primaryUser")
    ui.line(f"primary user: {user}")
    with connect(address, dry_run=dry_run) as mac:
        if not mac.succeeds(f"test -x {NIX_BIN}/nix"):
            msg = f"no Nix on {address} yet: run the bootstrap on the Mac"
            raise Error(msg)
        uid = mac.read(f"id -u {shlex.quote(user)} || true").strip()
        if not uid.isdigit():
            msg = f"no user {user} on {address}: the configuration's primary user must be the Mac's account"
            raise Error(msg)
        mac.keep_awake()
        full_disk_access(mac, int(uid), user)
        filevault(mac)
        upload_secrets(mac, machine)
        first_switch(mac, copy_flake(mac), machine)
        # Under --dry-run, the steps the switch would deploy.
        setup = declared_setup(machine) if dry_run else deployed_setup(mac)
        skipped = system_settings(mac, setup)
        ui.section("Left for you")
        ui.line(f"- FileVault: {mac.read('fdesetup status').strip()}")
        remind(machine, skipped)


def settings(machine: str, address: str | None, *, dry_run: bool) -> None:
    ui.section(machine)
    if address is None:
        address = deploy_host(machine)
        ui.line(f"address: {address}")
    with connect(address, dry_run=dry_run) as mac:
        setup = deployed_setup(mac)
        if setup is not None:
            full_disk_access(mac, setup.uid, setup.user)
        skipped = system_settings(mac, setup)
    if skipped:
        ui.section("Left for you")
        remind(machine, skipped)
