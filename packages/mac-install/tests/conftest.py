import re
import shlex
import subprocess
from dataclasses import dataclass, field

import pytest

ED25519 = "AAAAC3NzaC1lZDI1NTE5AAAAIFT/O0m15CY1Km5q4zRAKozCi2dRRIj7k9ExUtidt/16"


class Started:
    """A command started in the background, which ends when told to."""

    def terminate(self) -> None:
        pass

    def wait(self) -> int:
        return 0


@dataclass
class Commands:
    """Stands in for every command: the last rule whose pattern matches answers, else it succeeds silently."""

    rules: list[tuple[str, int, str]] = field(default_factory=list)
    here: list[str] = field(default_factory=list)
    on_mac: list[str] = field(default_factory=list)

    def on(self, pattern: str, output: str = "", *, code: int = 0) -> None:
        self.rules.insert(0, (pattern, code, output))

    def run(self, argv: list[str], **_: object) -> subprocess.CompletedProcess[bytes]:
        if argv[0] == "ssh":
            command = argv[-1]
            self.on_mac.append(command)
        else:
            command = shlex.join(argv)
            self.here.append(command)
        for pattern, code, output in self.rules:
            if re.search(pattern, command):
                return subprocess.CompletedProcess(argv, code, output.encode(), b"")
        return subprocess.CompletedProcess(argv, 0, b"", b"")

    def start(self, argv: list[str], **_: object) -> Started:
        self.run(argv)
        return Started()


@pytest.fixture
def commands(monkeypatch: pytest.MonkeyPatch) -> Commands:
    commands = Commands()
    monkeypatch.setattr(subprocess, "run", commands.run)
    monkeypatch.setattr(subprocess, "Popen", commands.start)
    return commands
