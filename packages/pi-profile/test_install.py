import json
import subprocess
import sys
import tempfile
from pathlib import Path

package = Path(sys.argv[1])
source = package / "share/pi-profile"
installer = package / "bin/pi-profile-install"
files = [Path("AGENTS.md"), Path("APPEND_SYSTEM.md"), Path("themes/tokyo-night.json")]
assert sorted(p.relative_to(source) for p in source.rglob("*") if p.is_file()) == sorted(files)
assert json.loads((source / "themes/tokyo-night.json").read_text())["name"] == "tokyo-night"


def install(destination, success=True, check=False):
    result = subprocess.run(
        [installer, *(["--check"] if check else []), destination],
        capture_output=True, text=True, env={"PATH": "/empty"}
    )
    assert (result.returncode == 0) == success, result.stderr
    return result


with tempfile.TemporaryDirectory() as temporary:
    destination = Path(temporary) / ".pi/agent"
    install(destination, check=True)
    assert not destination.exists(), "preflight must not create directories"
    destination.mkdir(parents=True)
    for name in ["settings.json", "auth.json", "models.json"]:
        (destination / name).write_text("untouched\n")

    # A late conflict must prevent even earlier files from being linked.
    conflict = destination / "themes/tokyo-night.json"
    conflict.parent.mkdir()
    conflict.write_text("local theme\n")
    assert "refusing to replace" in install(destination, success=False, check=True).stderr
    assert "refusing to replace" in install(destination, success=False).stderr
    assert not (destination / "AGENTS.md").exists()
    assert conflict.read_text() == "local theme\n"
    conflict.unlink()

    # Matching files can be adopted; repeated activation is harmless.
    (destination / "AGENTS.md").write_bytes((source / "AGENTS.md").read_bytes())
    install(destination, check=True)
    assert not (destination / "AGENTS.md").is_symlink()
    assert not (destination / "APPEND_SYSTEM.md").exists()
    install(destination)
    install(destination)
    for relative in files:
        assert (destination / relative).is_symlink()
        assert (destination / relative).resolve() == source / relative
    for name in ["settings.json", "auth.json", "models.json"]:
        assert (destination / name).read_text() == "untouched\n"

    # Prior package links can be upgraded, including dangling links after GC.
    agents = destination / "AGENTS.md"
    agents.unlink()
    agents.symlink_to("/nix/store/old-pi-profile/share/pi-profile/AGENTS.md")
    install(destination)
    assert agents.resolve() == source / "AGENTS.md"

    # An unrelated link remains user-owned, even if its contents match.
    agents.unlink()
    outside = Path(temporary) / "personal-instructions"
    outside.write_bytes((source / "AGENTS.md").read_bytes())
    agents.symlink_to(outside)
    install(destination, success=False)
    assert agents.readlink() == outside
    assert outside.read_bytes() == (source / "AGENTS.md").read_bytes()

print("PASS profile installation, adoption, upgrades, conflict refusal and mutable settings preservation")
