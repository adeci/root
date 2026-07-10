import json
import sys
from pathlib import Path


SECTION = "[/Script/Pal.PalGameWorldSettings]"
PREFIX = "OptionSettings=("


def split_assignments(value):
    parts = []
    current = []
    depth = 0
    quoted = False
    escaped = False

    for char in value:
        if escaped:
            current.append(char)
            escaped = False
            continue
        if char == "\\" and quoted:
            current.append(char)
            escaped = True
            continue
        if char == '"':
            quoted = not quoted
        elif not quoted and char == "(":
            depth += 1
        elif not quoted and char == ")" and depth > 0:
            depth -= 1
        elif not quoted and char == "," and depth == 0:
            parts.append("".join(current))
            current = []
            continue
        current.append(char)

    if current:
        parts.append("".join(current))
    return parts


def render_atom(value):
    if isinstance(value, bool):
        return "True" if value else "False"
    if isinstance(value, (int, float)):
        return str(value)
    return str(value)


def render(value):
    if isinstance(value, list):
        return f"({','.join(render_atom(item) for item in value)})"
    if isinstance(value, bool):
        return "True" if value else "False"
    if isinstance(value, (int, float)):
        return str(value)
    escaped = str(value).replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def load_json(path):
    with Path(path).open() as f:
        return json.load(f)


def patch_settings(
    settings_path,
    settings_json,
    admin_password_path,
    server_password_path,
    public_ip=None,
):
    settings = load_json(settings_json)
    settings["AdminPassword"] = Path(admin_password_path).read_text().strip()
    settings["ServerPassword"] = Path(server_password_path).read_text().strip()
    if public_ip:
        settings["PublicIP"] = public_ip

    rendered = {key: render(value) for key, value in settings.items()}

    path = Path(settings_path)
    lines = path.read_text().splitlines(keepends=True)

    for index, line in enumerate(lines):
        stripped = line.strip()
        if not stripped.startswith(PREFIX):
            continue

        content = stripped[len(PREFIX) :]
        if content.endswith(")"):
            content = content[:-1]

        entries = []
        for part in split_assignments(content):
            key = part.split("=", 1)[0]
            if "=" in part and key in rendered:
                entries.append(f"{key}={rendered.pop(key)}")
            else:
                entries.append(part)

        entries.extend(f"{key}={rendered[key]}" for key in sorted(rendered))
        lines[index] = f"OptionSettings=({','.join(entries)})\n"
        break
    else:
        entries = ",".join(f"{key}={rendered[key]}" for key in sorted(rendered))
        lines.extend([f"{SECTION}\n", f"OptionSettings=({entries})\n"])

    path.write_text("".join(lines))


if __name__ == "__main__":
    if len(sys.argv) not in (5, 6):
        raise SystemExit(
            "usage: palworld-patch-settings <settings.ini> <settings.json> "
            "<admin-password> <server-password> [public-ip]"
        )
    patch_settings(*sys.argv[1:])
