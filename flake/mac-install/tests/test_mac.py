import io
import subprocess
import tarfile
from pathlib import Path

from mac_install.mac import HostKey, Trust, record, recorded, secrets_tarball, trust

from .conftest import ED25519

OTHER = "AAAAC3NzaC1lZDI1NTE5AAAAIOf0URzmusd83C/zYSVyJotzH+hqL3KiKAVlxTvuDpYq"
KEY = HostKey("192.0.2.7", "ssh-ed25519", ED25519)


def ssh_keygen(*args: str | Path) -> str:
    return subprocess.run(
        ["ssh-keygen", *args], capture_output=True, text=True, check=True
    ).stdout


def test_fingerprint_is_what_ssh_keygen_prints(tmp_path: Path) -> None:
    (tmp_path / "key.pub").write_text(f"ssh-ed25519 {ED25519}\n")
    assert KEY.fingerprint == ssh_keygen("-lf", tmp_path / "key.pub").split()[1]


def test_recorded_reads_hashed_lines_and_skips_markers(tmp_path: Path) -> None:
    known_hosts = tmp_path / "known_hosts"
    known_hosts.write_text(
        f"192.0.2.7 ssh-ed25519 {ED25519}\n"
        f"@revoked 192.0.2.7 ssh-ed25519 {OTHER}\n"
        f"@cert-authority * ssh-ed25519 {OTHER}\n"
        f"192.0.2.8 ssh-ed25519 {OTHER}\n"
    )
    ssh_keygen("-H", "-f", known_hosts)
    [key] = recorded("192.0.2.7", known_hosts)
    assert key.hosts.startswith("|1|")
    assert (key.algorithm, key.key) == ("ssh-ed25519", ED25519)


def test_trust() -> None:
    hashed = HostKey("|1|c2FsdA==|aGFzaA==", "ssh-ed25519", ED25519)
    other = HostKey("192.0.2.7", "ssh-ed25519", OTHER)
    rsa = HostKey("192.0.2.7", "ssh-rsa", OTHER)
    assert trust(KEY, [rsa, hashed]) is Trust.KNOWN
    assert trust(KEY, [other]) is Trust.CHANGED
    # Another kind of key is no claim about this one.
    assert trust(KEY, [rsa]) is Trust.NEW
    assert trust(KEY, []) is Trust.NEW


def test_record_replaces_what_known_hosts_had_for_the_address(tmp_path: Path) -> None:
    known_hosts = tmp_path / "known_hosts"
    known_hosts.write_text(f"192.0.2.7 ssh-ed25519 {OTHER}\n")
    ssh_keygen("-H", "-f", known_hosts)
    with known_hosts.open("a") as f:
        f.write(f"192.0.2.8 ssh-ed25519 {OTHER}\n")
    record(KEY, known_hosts)
    assert known_hosts.read_text() == (
        f"192.0.2.8 ssh-ed25519 {OTHER}\n192.0.2.7 ssh-ed25519 {ED25519}\n"
    )


def test_record_starts_known_hosts(tmp_path: Path) -> None:
    known_hosts = tmp_path / ".ssh" / "known_hosts"
    record(KEY, known_hosts)
    assert known_hosts.read_text() == f"192.0.2.7 ssh-ed25519 {ED25519}\n"
    assert known_hosts.parent.stat().st_mode & 0o777 == 0o700


def test_secrets_are_root_owned_with_their_modes(tmp_path: Path) -> None:
    (tmp_path / "key.txt").write_text("AGE-SECRET-KEY-1")
    (tmp_path / "key.txt").chmod(0o600)
    (tmp_path / "activation" / "gen").mkdir(parents=True)
    (tmp_path / "activation" / "gen" / "file").write_text("x")
    (tmp_path / "activation" / "gen" / "file").chmod(0o440)
    tmp_path.chmod(0o700)
    with tarfile.open(fileobj=io.BytesIO(secrets_tarball(tmp_path))) as tar:
        members = {m.name: m for m in tar.getmembers()}
    assert set(members) == {
        ".",
        "./key.txt",
        "./activation",
        "./activation/gen",
        "./activation/gen/file",
    }
    assert {(m.uid, m.gid, m.uname, m.gname) for m in members.values()} == {
        (0, 0, "root", "wheel")
    }
    # The upload directory itself takes the mode of ".".
    assert members["."].mode == 0o700
    assert members["./key.txt"].mode == 0o600
    assert members["./activation/gen/file"].mode == 0o440
