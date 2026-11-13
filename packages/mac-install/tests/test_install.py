import json
import re
import time
from collections.abc import Callable
from pathlib import Path

import pytest

from mac_install import Error, mac, ui
from mac_install.install import (
    FDA_CHECK,
    Setup,
    Step,
    full_disk_access,
    install,
    parse_setup,
    settings,
)

from .conftest import ED25519, Commands

# What a real Mac's /etc/mac-setup.json holds for a step.
SCROLL = "/usr/bin/sqlite3 '/Library/Application Support/com.apple.TCC/TCC.db' 'select auth_value from access where service = '\\''kTCCServiceAccessibility'\\'' and client = '\\''com.pilotmoon.scroll-reverser'\\''' 2>/dev/null | /usr/bin/grep -qx 2"
URL = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
SCROLL_REVERSER: dict[str, object] = {
    "check": SCROLL,
    "instructions": "Turn on Scroll Reverser.",
    "name": "Scroll Reverser",
    "restart": ["gui/org.nixos.scroll-reverser"],
    "url": URL,
}
SETUP: dict[str, object] = {"steps": [SCROLL_REVERSER], "uid": 501, "user": "ada"}

# What a dry run may run: it only reads, here and on the Mac.
READ_ONLY = [
    r"nix eval ",
    r"ssh-keyscan ",
    r"clan vars check ",
    r"nix flake archive --json --dry-run \.$",
    r"test -[ex] ",
    r"id -u ",
    r"/usr/bin/sqlite3 ",
    r"fdesetup (isactive|status)$",
    r"readlink /run/current-system",
    r"\[ -e /etc/nix/nix\.conf \] && \[ ! -L /etc/nix/nix\.conf \]$",
    r"cat /etc/mac-setup\.json$",
]


def setup_json(**changes: object) -> str:
    return json.dumps(SETUP | changes)


def test_parse_reads_what_the_module_writes() -> None:
    restart = ("gui/org.nixos.scroll-reverser",)
    step = Step("Scroll Reverser", URL, "Turn on Scroll Reverser.", SCROLL, restart)
    assert parse_setup(setup_json()) == Setup("ada", 501, (step,))


def test_parse_takes_steps_without_a_check() -> None:
    setup = parse_setup(setup_json(steps=[SCROLL_REVERSER | {"check": None}]))
    assert setup.steps[0].check is None


@pytest.mark.parametrize(
    ("text", "message"),
    [
        ("not json", r"/etc/mac-setup\.json: Expecting value"),
        ("[]", r"the top level should be an object, not \[\]"),
        (setup_json(uid="501"), r"uid should be a number, not \"501\""),
        # Python's bool is an int; JSON's true is not.
        (setup_json(uid=True), r"uid should be a number, not true"),
        (setup_json(steps=["x"]), r"steps\[0\] should be an object"),
        (setup_json(steps=[{}]), r"steps\[0\]\.restart should be a list, not null"),
        (
            setup_json(steps=[{"restart": [1]}]),
            r"steps\[0\]\.restart should be a list of strings",
        ),
        (setup_json(steps=[{"restart": []}]), r"steps\[0\]\.name should be a string"),
        (
            setup_json(steps=[{"check": 1}]),
            r"steps\[0\]\.check should be a string or null",
        ),
    ],
)
def test_parse_says_what_is_wrong_and_where(text: str, message: str) -> None:
    with pytest.raises(Error, match=message):
        parse_setup(text)


@pytest.fixture
def macbook(
    commands: Commands, monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> Commands:
    """A Mac primed by the bootstrap, a flake that configures it, and a person who confirms its key."""
    monkeypatch.setenv("HOME", str(tmp_path))
    monkeypatch.setattr(mac, "probe", lambda address: None)
    monkeypatch.setattr(ui, "ask", lambda question: True)
    commands.on(r"primaryUser'$", "ada")
    commands.on(r"secretUploadDirectory'$", "/var/lib/sops-nix")
    commands.on(r"environment\.etc'$", json.dumps(setup_json()))
    commands.on(r"^ssh-keyscan ", f"192.0.2.7 ssh-ed25519 {ED25519}\n")
    commands.on(r"^nix flake archive ", json.dumps({"path": "/nix/store/aaaa-source"}))
    commands.on(r"^id -u ada", "501\n")
    commands.on(r"^cat /etc/mac-setup\.json$", setup_json())
    return commands


def test_dry_run_only_reads(macbook: Commands, tmp_path: Path) -> None:
    # Every step that would change something has something to change.
    macbook.on(r"^/usr/bin/sqlite3 ", code=1)
    macbook.on(r"^clan vars check ", "macbook: 1 var to generate\n", code=1)
    install("macbook", "192.0.2.7", dry_run=True)
    ran = macbook.here + macbook.on_mac
    assert [c for c in ran if not any(re.match(p, c) for p in READ_ONLY)] == []
    assert not (tmp_path / ".ssh" / "known_hosts").exists()


def test_an_unconfirmed_host_key_stops_everything(
    macbook: Commands, monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    monkeypatch.setattr(ui, "ask", lambda question: False)
    with pytest.raises(Error, match="host key not confirmed"):
        install("macbook", "192.0.2.7", dry_run=False)
    assert macbook.on_mac == []
    assert not (tmp_path / ".ssh" / "known_hosts").exists()


@pytest.mark.parametrize("flow", [install, settings])
def test_a_skipped_step_is_reported_and_reminded(
    macbook: Commands,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
    flow: Callable[..., None],
) -> None:
    macbook.on(re.escape(SCROLL), code=1)
    # Enter, as soon as the wait begins.
    monkeypatch.setattr(ui, "until", lambda condition: condition())
    flow("macbook", "192.0.2.7", dry_run=False)
    out = capsys.readouterr().out
    assert "! Scroll Reverser: skipped; its check still fails" in out
    assert "✓ Scroll Reverser" not in out
    assert "- System Settings: Scroll Reverser (mac-install settings macbook)" in out


def test_full_disk_access_gives_up_after_five_minutes(
    commands: Commands, monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    now = 0.0

    def sleep(seconds: float) -> None:
        nonlocal now
        now += seconds
        assert now < 3600, "still waiting an hour later"

    monkeypatch.setattr(time, "monotonic", lambda: now)
    monkeypatch.setattr(time, "sleep", sleep)
    commands.on(re.escape(FDA_CHECK), code=1)
    socket = tmp_path / "ssh"
    connection = mac.Mac("root@192.0.2.7", dry_run=False, control=socket, pinned=[])
    with pytest.raises(Error, match="still off after 5 minutes"):
        full_disk_access(connection, 501, "ada")
    assert now >= 300
