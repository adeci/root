"""Local and remote commands, and the host key."""

import base64
import contextlib
import hashlib
import io
import os
import shlex
import socket
import subprocess
import tarfile
import tempfile
from collections.abc import Iterator, Mapping, Sequence
from dataclasses import dataclass
from enum import Enum
from pathlib import Path
from typing import Self

from . import Error, ui

# The Nix installer's profile; before nix-darwin it isn't on root's PATH over SSH.
NIX_BIN = "/nix/var/nix/profiles/default/bin"


class CommandError(Error):
    """A command that failed."""


def run(  # noqa: PLR0913 - the options are keyword-only
    argv: Sequence[str],
    *,
    env: Mapping[str, str] | None = None,
    stdin: bytes | None = None,
    capture: bool = False,
    quiet: bool = False,
    interactive: bool = False,
    check: bool = True,
) -> subprocess.CompletedProcess[str]:
    """Only `interactive` commands read the terminal, so none eats keypresses meant for a prompt."""
    stdout = None
    if capture:
        stdout = subprocess.PIPE
    elif quiet:
        stdout = subprocess.DEVNULL
    try:
        completed = subprocess.run(
            argv,
            env=None if env is None else {**os.environ, **env},
            input=stdin,
            stdin=None if interactive or stdin is not None else subprocess.DEVNULL,
            stdout=stdout,
            stderr=subprocess.PIPE if quiet else None,
            check=False,
        )
    except OSError as e:
        msg = f"can't run {argv[0]}: {e.strerror}"
        raise Error(msg) from e
    if check and completed.returncode != 0:
        msg = f"`{shlex.join(argv)}` failed with exit code {completed.returncode}"
        if quiet and completed.stderr.strip():
            msg += f":\n{completed.stderr.decode(errors='replace').rstrip()}"
        raise CommandError(msg)
    output = completed.stdout.decode(errors="replace") if capture else ""
    return subprocess.CompletedProcess(argv, completed.returncode, output)


def probe(address: str) -> None:
    """Fail with what to do about it unless something answers on port 22."""
    try:
        socket.create_connection((address, 22), timeout=5).close()
    except ConnectionRefusedError:
        msg = f"{address} is up but SSH is off: run the bootstrap on the Mac"
        raise Error(msg) from None
    except socket.gaierror:
        msg = f"can't resolve {address}: use the address the bootstrap printed"
        raise Error(msg) from None
    except OSError as e:
        reason = e.strerror or str(e) or "timed out"
        msg = f"{address} doesn't answer on port 22 (asleep, wrong address, or another network): {reason}"
        raise Error(msg) from None


@dataclass(frozen=True)
class HostKey:
    """A known_hosts line: `<hosts> <algorithm> <base64 key>`."""

    hosts: str
    algorithm: str
    key: str

    @classmethod
    def parse(cls, line: str) -> Self | None:
        match line.split():
            # Comments, and @revoked or @cert-authority lines, which never vouch for a key.
            case [hosts, algorithm, key, *_] if not hosts.startswith(("#", "@")):
                return cls(hosts, algorithm, key)
            case _:
                return None

    @property
    def fingerprint(self) -> str:
        digest = hashlib.sha256(base64.b64decode(self.key)).digest()
        return "SHA256:" + base64.b64encode(digest).decode().rstrip("=")

    def __str__(self) -> str:
        return f"{self.hosts} {self.algorithm} {self.key}"


class Trust(Enum):
    KNOWN = "known"
    CHANGED = "changed"
    NEW = "new"


def trust(offered: HostKey, known: list[HostKey]) -> Trust:
    same_kind = [key for key in known if key.algorithm == offered.algorithm]
    if any(key.key == offered.key for key in same_kind):
        return Trust.KNOWN
    return Trust.CHANGED if same_kind else Trust.NEW


def scan(address: str) -> HostKey:
    argv = ["ssh-keyscan", "-T", "5", "-t", "ed25519", address]
    for line in run(argv, capture=True, quiet=True, check=False).stdout.splitlines():
        key = HostKey.parse(line)
        if key is not None:
            return key
    msg = f"SSH on {address} has no ed25519 host key yet: run `sudo ssh-keygen -A` on the Mac"
    raise Error(msg)


def recorded(address: str, known_hosts: Path) -> list[HostKey]:
    if not known_hosts.exists():
        return []
    argv = ["ssh-keygen", "-F", address, "-f", str(known_hosts)]
    out = run(argv, capture=True, quiet=True, check=False).stdout
    keys = (HostKey.parse(line) for line in out.splitlines())
    return [key for key in keys if key is not None]


def record(key: HostKey, known_hosts: Path) -> None:
    """Make `key` the only one known_hosts has for its address."""
    if known_hosts.exists():
        argv = ["ssh-keygen", "-R", key.hosts, "-f", str(known_hosts)]
        run(argv, quiet=True, check=False)
    known_hosts.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    with known_hosts.open("a") as f:
        f.write(f"{key}\n")


def secrets_tarball(directory: Path) -> bytes:
    """`directory` as root:wheel will own it on the Mac, with the modes clan gave each file."""

    def as_root(info: tarfile.TarInfo) -> tarfile.TarInfo:
        info.uid, info.gid, info.uname, info.gname = 0, 0, "root", "wheel"
        return info

    buffer = io.BytesIO()
    with tarfile.open(fileobj=buffer, mode="w") as tar:
        tar.add(directory, arcname=".", filter=as_root)
    return buffer.getvalue()


def ssh_options(*settings: str) -> list[str]:
    return [arg for setting in settings for arg in ("-o", setting)]


@dataclass
class Mac:
    """root on the Mac: commands share one connection, except where a new session matters."""

    target: str
    dry_run: bool
    # The shared connection's socket.
    control: Path
    # ssh options that make the key --dry-run trusts for its own run the only one.
    pinned: list[str]
    awake: subprocess.Popen[bytes] | None = None

    @property
    def shared(self) -> list[str]:
        """ssh options for the shared connection, which nix uses too through NIX_SSHOPTS."""
        control = f"ControlPath={self.control}"
        persist = ssh_options("ControlMaster=auto", control, "ControlPersist=10m")
        return [*persist, *self.pinned]

    def ssh(self, command: str, *, fresh: bool = False) -> list[str]:
        options = [*ssh_options("ControlPath=none"), *self.pinned]
        return ["ssh", *(options if fresh else self.shared), self.target, command]

    def succeeds(self, command: str, *, fresh: bool = False) -> bool:
        argv = self.ssh(command, fresh=fresh)
        return run(argv, quiet=True, check=False).returncode == 0

    def read(self, command: str) -> str:
        return run(self.ssh(command), capture=True, quiet=True).stdout

    def change(self, command: str, *, fresh: bool = False, check: bool = True) -> None:
        """Run a command that changes the Mac; --dry-run only shows it, and an unchecked one runs quietly."""
        if self.dry_run:
            ui.would(f"run on the Mac: {command}")
        else:
            run(self.ssh(command, fresh=fresh), quiet=not check, check=check)

    def open_as(self, uid: int, user: str, url: str, *, fresh: bool = False) -> None:
        """Open `url` in the user's session: macOS takes some settings only from a person."""
        user, url = shlex.quote(user), shlex.quote(url)
        self.change(f"launchctl asuser {uid} sudo -u {user} open {url}", fresh=fresh)

    def keep_awake(self) -> None:
        """caffeinate in its own session with a terminal, so the hangup when it ends stops it, even if this machine drops off."""
        if self.dry_run:
            ui.would("keep the Mac awake while this runs (lid open)")
            return
        options = [*ssh_options("ControlPath=none"), *self.pinned]
        self.awake = subprocess.Popen(
            ["ssh", "-tt", *options, self.target, "caffeinate -dimsu"],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )

    def disconnect(self) -> None:
        """End the shared connection; the next command opens a new session."""
        if self.control.exists():
            options = ssh_options(f"ControlPath={self.control}")
            run(["ssh", *options, "-O", "exit", self.target], quiet=True, check=False)

    def close(self) -> None:
        if self.awake is not None:
            self.awake.terminate()
            self.awake.wait()
            self.awake = None
        self.disconnect()


@contextlib.contextmanager
def connect(address: str, *, dry_run: bool) -> Iterator[Mac]:
    """root on the Mac, over a host key that known_hosts has or the person running this confirmed."""
    ui.section(f"Host key of {address}")
    probe(address)
    key = scan(address)
    known_hosts = Path.home() / ".ssh" / "known_hosts"
    verdict = trust(key, recorded(address, known_hosts))
    if verdict is Trust.KNOWN:
        ui.done(f"{key.fingerprint}, already in ~/.ssh/known_hosts")
    else:
        if verdict is Trust.CHANGED:
            ui.warn(f"~/.ssh/known_hosts has another key for {address}")
        ui.line(key.fingerprint)
        if not ui.ask("Same as the one the Mac printed?"):
            msg = "host key not confirmed"
            raise Error(msg)
        if dry_run:
            ui.would("record it in ~/.ssh/known_hosts")
        else:
            record(key, known_hosts)
    with tempfile.TemporaryDirectory(prefix="mac-install-") as tmp:
        pinned = []
        if dry_run:
            (Path(tmp) / "known_hosts").write_text(f"{key}\n")
            pinned = ssh_options(
                f"UserKnownHostsFile={tmp}/known_hosts", "StrictHostKeyChecking=yes"
            )
        mac = Mac(f"root@{address}", dry_run, Path(tmp) / "ssh", pinned)
        with contextlib.closing(mac):
            yield mac
