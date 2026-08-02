#!@python@
"""Runtime-only controls for niri displays."""

from __future__ import annotations

import argparse
import decimal
import fcntl
import json
import os
import re
import shlex
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Iterable

NIRI = os.environ.get("NIRI_DISPLAY_NIRI", "@niri@")
WL_MIRROR = os.environ.get("NIRI_DISPLAY_WL_MIRROR", "@wl_mirror@")
SYSTEMCTL = os.environ.get("NIRI_DISPLAY_SYSTEMCTL", "@systemctl@")
SYSTEMD_RUN = os.environ.get("NIRI_DISPLAY_SYSTEMD_RUN", "@systemd_run@")
UNIT = "niri-display-mirror.service"
UNIT_DESCRIPTION = "Niri display mirror owned by niri-display"
UNIT_OWNER_MARKER = "NIRI_DISPLAY_OWNER=niri-display-v1"
UNIT_PROPERTY_NAMES = (
    "LoadState", "Transient", "Description", "Environment", "ExecStart",
    "ActiveState", "SubState", "Result", "ExecMainCode", "ExecMainStatus",
)
STARTUP_WINDOW_SECONDS = 0.5
STARTUP_POLL_SECONDS = 0.025
MODE_RE = re.compile(r"^(?P<width>[1-9][0-9]*)x(?P<height>[1-9][0-9]*)(?:@(?P<hz>[0-9]+(?:\.[0-9]{1,3})?))?$")
SCALE_RE = re.compile(r"^(?:[0-9]+(?:\.[0-9]+)?|\.[0-9]+)$")
NIX_STORE_WL_MIRROR_RE = re.compile(
    r"/nix/store/[0123456789abcdfghijklmnpqrsvwxyz]{32}-[A-Za-z0-9+._?=-]+/bin/wl-mirror"
)


class DisplayError(RuntimeError):
    pass


def run(command: list[str], *, check: bool = True) -> subprocess.CompletedProcess[str]:
    try:
        result = subprocess.run(command, text=True, capture_output=True, check=False)
    except OSError as exc:
        raise DisplayError(f"could not execute {command[0]}: {exc}") from exc
    if check and result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip() or f"exit {result.returncode}"
        raise DisplayError(f"{command[0]} failed: {detail}")
    return result


def runtime_paths() -> tuple[Path, Path, Path]:
    value = os.environ.get("XDG_RUNTIME_DIR", "")
    if not value:
        raise DisplayError("XDG_RUNTIME_DIR is not set; run this from a graphical user session")
    root = Path(value)
    if not root.is_dir():
        raise DisplayError(f"XDG_RUNTIME_DIR is not a directory: {root}; set it to a runtime directory and retry")
    state_dir = root / "niri-display"
    return state_dir, state_dir / "mirror.json", state_dir / "lock"


def locked():
    state_dir, _, lock_path = runtime_paths()
    state_dir.mkdir(mode=0o700, exist_ok=True)
    os.chmod(state_dir, 0o700)
    handle = lock_path.open("a+", encoding="utf-8")
    fcntl.flock(handle, fcntl.LOCK_EX)
    return handle


def parse_json_result(result: subprocess.CompletedProcess[str], label: str) -> Any:
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip() or f"exit {result.returncode}"
        raise DisplayError(f"could not query {label}: {detail}")
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        raise DisplayError(f"invalid JSON from {label}: {exc.msg}") from exc


def require_int(value: Any, label: str, *, minimum: int | None = None) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        raise DisplayError(f"invalid {label} in niri output data")
    if minimum is not None and value < minimum:
        raise DisplayError(f"invalid {label} in niri output data")
    return value


def require_number(value: Any, label: str) -> int | float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise DisplayError(f"invalid {label} in niri output data")
    if decimal.Decimal(str(value)) <= 0:
        raise DisplayError(f"invalid {label} in niri output data")
    return value


def format_mhz(millihertz: int) -> str:
    require_int(millihertz, "refresh rate", minimum=1)
    whole, fraction = divmod(millihertz, 1000)
    return str(whole) if fraction == 0 else f"{whole}.{fraction:03d}".rstrip("0")


def hz_to_mhz(value: str) -> int:
    if not re.fullmatch(r"[0-9]+(?:\.[0-9]{1,3})?", value):
        raise DisplayError(f"invalid refresh rate: {value}")
    whole, dot, fraction = value.partition(".")
    return int(whole) * 1000 + int((fraction if dot else "").ljust(3, "0") or "0")


def selection_key(connector: str, make: str, model: str, serial: str | None) -> str:
    """Return the canonical public key for one current physical output."""
    return json.dumps(
        {"connector": connector, "make": make, "model": model, "serial": serial},
        ensure_ascii=True,
        separators=(",", ":"),
        sort_keys=True,
    )


def parse_selection_key(value: str, label: str) -> dict[str, str | None]:
    try:
        parsed = json.loads(value)
    except (TypeError, json.JSONDecodeError) as exc:
        raise DisplayError(f"invalid {label} selection key; refresh displays and select it again") from exc
    if not isinstance(parsed, dict) or set(parsed) != {"connector", "make", "model", "serial"}:
        raise DisplayError(f"invalid {label} selection key; refresh displays and select it again")
    connector, make, model, serial = (
        parsed["connector"], parsed["make"], parsed["model"], parsed["serial"]
    )
    if not isinstance(connector, str) or not isinstance(make, str) or not isinstance(model, str):
        raise DisplayError(f"invalid {label} selection key; refresh displays and select it again")
    if serial is not None and not isinstance(serial, str):
        raise DisplayError(f"invalid {label} selection key; refresh displays and select it again")
    if selection_key(connector, make, model, serial) != value:
        raise DisplayError(f"invalid {label} selection key; refresh displays and select it again")
    return parsed


def normalize_outputs(raw: Any, focused_name: str | None) -> list[dict[str, Any]]:
    if not isinstance(raw, dict):
        raise DisplayError("niri outputs JSON must be an object")
    outputs: list[dict[str, Any]] = []
    for connector in sorted(raw):
        value = raw[connector]
        if not isinstance(connector, str) or not connector or not isinstance(value, dict):
            raise DisplayError("invalid output entry in niri output data")
        embedded_name = value.get("name", connector)
        if embedded_name != connector:
            raise DisplayError(f"ambiguous output identity: key {connector!r} != name {embedded_name!r}")
        make = value.get("make", "")
        model = value.get("model", "")
        serial = value.get("serial")
        if not isinstance(make, str) or not isinstance(model, str) or not (serial is None or isinstance(serial, str)):
            raise DisplayError(f"invalid identity for output {connector}")

        raw_modes = value.get("modes")
        if not isinstance(raw_modes, list):
            raise DisplayError(f"invalid modes for output {connector}")
        modes: list[dict[str, Any]] = []
        for index, raw_mode in enumerate(raw_modes):
            if not isinstance(raw_mode, dict):
                raise DisplayError(f"invalid mode for output {connector}")
            width = require_int(raw_mode.get("width"), "mode width", minimum=1)
            height = require_int(raw_mode.get("height"), "mode height", minimum=1)
            refresh_mhz = require_int(raw_mode.get("refresh_rate"), "refresh rate", minimum=1)
            preferred = raw_mode.get("is_preferred", False)
            if not isinstance(preferred, bool):
                raise DisplayError(f"invalid mode flags for output {connector}")
            modes.append({
                "index": index,
                "width": width,
                "height": height,
                "refresh_mhz": refresh_mhz,
                "refresh_hz": format_mhz(refresh_mhz),
                "preferred": preferred,
                "key": f"{width}x{height}@{format_mhz(refresh_mhz)}",
            })

        current_index = value.get("current_mode")
        if current_index is not None:
            current_index = require_int(current_index, "current mode index", minimum=0)
            if current_index >= len(modes):
                raise DisplayError(f"current mode index out of range for output {connector}")
        logical_raw = value.get("logical")
        logical = None
        if logical_raw is not None:
            if not isinstance(logical_raw, dict):
                raise DisplayError(f"invalid logical rectangle for output {connector}")
            logical = {
                "x": require_int(logical_raw.get("x"), "logical x"),
                "y": require_int(logical_raw.get("y"), "logical y"),
                "width": require_int(logical_raw.get("width"), "logical width", minimum=1),
                "height": require_int(logical_raw.get("height"), "logical height", minimum=1),
                "scale": require_number(logical_raw.get("scale"), "logical scale"),
                "transform": logical_raw.get("transform", "Normal"),
            }
            if not isinstance(logical["transform"], str):
                raise DisplayError(f"invalid transform for output {connector}")
        # Interlaced modes can be absent from modes while logical remains set.
        active = logical is not None
        current = modes[current_index] if current_index is not None else None
        outputs.append({
            "name": connector,
            "make": make,
            "model": model,
            "serial": serial,
            "selection_key": selection_key(connector, make, model, serial),
            "identity": " ".join(part for part in (make, model, serial or "") if part).strip(),
            "friendly": " ".join(part for part in (make, model) if part).strip() or connector,
            "active": active,
            "focused": connector == focused_name,
            "current_mode": current,
            "logical": logical,
            "modes": modes,
        })
    if focused_name is not None and not any(output["name"] == focused_name for output in outputs):
        raise DisplayError(f"focused output {focused_name!r} is missing from outputs")
    return outputs


def get_outputs() -> list[dict[str, Any]]:
    raw = parse_json_result(run([NIRI, "msg", "--json", "outputs"], check=False), "niri outputs")
    focused_raw = parse_json_result(
        run([NIRI, "msg", "--json", "focused-output"], check=False), "niri focused output"
    )
    if focused_raw is None:
        focused_name = None
    elif isinstance(focused_raw, dict) and isinstance(focused_raw.get("name"), str):
        focused_name = focused_raw["name"]
    else:
        raise DisplayError("invalid JSON from niri focused output")
    return normalize_outputs(raw, focused_name)


def aliases(output: dict[str, Any]) -> set[str]:
    values = {output["name"]}
    make_model = " ".join(part for part in (output["make"], output["model"]) if part).strip()
    if make_model:
        values.add(make_model)
    if output["identity"]:
        values.add(output["identity"])
    return values


def resolve_output(outputs: Iterable[dict[str, Any]], identity: str, *, active: bool = False) -> dict[str, Any]:
    exact_connector = [output for output in outputs if output["name"] == identity]
    matches = exact_connector or [output for output in outputs if identity in aliases(output)]
    if not matches:
        raise DisplayError(f"output not found: {identity}; run niri-display outputs to list available outputs")
    if len(matches) != 1:
        names = ", ".join(output["name"] for output in matches)
        raise DisplayError(f"ambiguous output {identity!r}; use a connector name: {names}")
    output = matches[0]
    if active and not output["active"]:
        raise DisplayError(f"output is not active: {output['name']}; enable it and retry")
    return output


def resolve_action_output(
    outputs: Iterable[dict[str, Any]],
    identity: str,
    expected_key: str | None,
    label: str,
    *,
    active: bool = False,
) -> dict[str, Any]:
    """Resolve a CLI identity and, when supplied, fail closed on a stale UI key."""
    output_list = list(outputs)
    output = resolve_output(output_list, identity, active=active)
    if expected_key is None:
        return output
    expected = parse_selection_key(expected_key, label)
    matches = [candidate for candidate in output_list if candidate["selection_key"] == expected_key]
    if len(matches) > 1:
        raise DisplayError(f"ambiguous {label} selection key; refresh displays and select it again")
    if (
        len(matches) != 1
        or matches[0] is not output
        or expected["connector"] != output["name"]
    ):
        raise DisplayError(
            f"{label} selection no longer matches connector {output['name']}; "
            "refresh displays and select it again"
        )
    return output


def action_key(args: argparse.Namespace, name: str) -> str | None:
    """Return an optional UI selection key, including for menu namespaces."""
    return getattr(args, f"{name}_key", None)


def require_expected_keys(args: argparse.Namespace, *names: str) -> None:
    supplied = [action_key(args, name) is not None for name in names]
    if any(supplied) and not all(supplied):
        flags = " and ".join(f"--{name.replace('_', '-')}-key" for name in names)
        raise DisplayError(f"expected selection validation requires {flags}")


def mirror_active() -> bool:
    return run([SYSTEMCTL, "--user", "is-active", "--quiet", UNIT], check=False).returncode == 0


def unit_properties() -> dict[str, str] | None:
    result = run(
        [SYSTEMCTL, "--user", "show", *(f"--property={name}" for name in UNIT_PROPERTY_NAMES), UNIT],
        check=False,
    )
    if result.returncode in (3, 4, 5):
        return None
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip() or f"exit {result.returncode}"
        raise DisplayError(f"could not inspect mirror unit ownership: {detail}")
    properties: dict[str, str] = {}
    for line in result.stdout.splitlines():
        key, separator, value = line.partition("=")
        if separator and key in UNIT_PROPERTY_NAMES:
            properties[key] = value
    # systemd 261 can return success when the unit is absent.
    if properties.get("LoadState") == "not-found":
        return None
    return properties or None


def exec_start_argv(value: str) -> list[str] | None:
    # Accept only systemctl's single-command ExecStart rendering. systemd 261
    # omits the final metadata separator before the closing brace.
    metadata_field = (
        r"[A-Za-z_][A-Za-z0-9_]*="
        r"(?:(?!\s+[A-Za-z_][A-Za-z0-9_]*=)[^;{}])*"
    )
    match = re.fullmatch(
        rf"\{{\s*path=(?P<path>[^\s;{{}}]+)\s*;\s*argv\[\]=(?P<argv>[^;{{}}]*)\s*;\s*"
        rf"(?:{metadata_field}\s*;\s*)*(?:{metadata_field}\s*)?\}}",
        value,
    )
    if match is None:
        return None
    try:
        argv = shlex.split(match.group("argv"))
    except ValueError:
        return None
    if not argv or argv[0] != match.group("path"):
        return None
    return argv


def is_mirror_command(value: str) -> bool:
    argv = exec_start_argv(value)
    if argv is None or len(argv) != 4 or NIX_STORE_WL_MIRROR_RE.fullmatch(argv[0]) is None:
        return False
    target, source = argv[2:]
    return argv[1] == "--fullscreen-output" and target != source and all(
        name and not name.startswith("-") for name in (target, source)
    )


def exec_start_matches(value: str, expected: list[str]) -> bool:
    return is_mirror_command(value) and exec_start_argv(value) == expected


def unit_ownership(properties: dict[str, str] | None = None) -> bool | None:
    if properties is None:
        properties = unit_properties()
    if properties is None:
        return None
    if properties.get("Transient") != "yes" or not is_mirror_command(properties.get("ExecStart", "")):
        return False
    environment = properties.get("Environment", "").split()
    if UNIT_OWNER_MARKER in environment:
        return True
    # The first deployed version used its description as the ownership marker.
    return properties.get("Description") == UNIT_DESCRIPTION


def ownership_collision() -> DisplayError:
    return DisplayError(
        f"cannot modify {UNIT}: it is not owned by niri-display; "
        f"inspect it with: systemctl --user show {UNIT} "
        "-p Description -p Environment -p ExecStart"
    )


def unit_health(properties: dict[str, str]) -> str:
    return ", ".join(
        f"{name}={properties.get(name, '<missing>')}"
        for name in ("ActiveState", "SubState", "Result", "ExecMainCode", "ExecMainStatus")
    )


def startup_diagnostics() -> str:
    result = run(
        [SYSTEMCTL, "--user", "status", "--no-pager", "--lines=10", UNIT], check=False
    )
    return (result.stdout.strip() or result.stderr.strip()).strip()


def cleanup_started_unit(expected: list[str], properties: dict[str, str] | None) -> None:
    remove_state()
    if unit_ownership(properties) is not True or not exec_start_matches(
        properties.get("ExecStart", "") if properties else "", expected
    ):
        return
    run([SYSTEMCTL, "--user", "stop", UNIT], check=False)
    run([SYSTEMCTL, "--user", "reset-failed", UNIT], check=False)


def confirm_started_unit(expected: list[str]) -> None:
    deadline = time.monotonic() + STARTUP_WINDOW_SECONDS
    properties: dict[str, str] | None = None
    failure = ""
    while True:
        properties = unit_properties()
        if properties is None:
            failure = "started mirror unit disappeared"
            break
        if unit_ownership(properties) is not True:
            failure = "started mirror unit ownership did not match"
            break
        if not exec_start_matches(properties.get("ExecStart", ""), expected):
            failure = "started mirror unit command did not match"
            break
        healthy = (
            properties.get("ActiveState") == "active"
            and properties.get("SubState") == "running"
            and properties.get("Result") in ("", "success")
            and properties.get("ExecMainStatus") in ("", "0")
        )
        if not healthy:
            failure = f"mirror service failed during startup ({unit_health(properties)})"
            break
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            return
        time.sleep(min(STARTUP_POLL_SECONDS, remaining))

    diagnostics = startup_diagnostics()
    cleanup_started_unit(expected, properties)
    if diagnostics:
        failure = f"{failure}\n{diagnostics}"
    raise DisplayError(failure)


def read_mirror_state() -> dict[str, Any] | None:
    _, state_path, _ = runtime_paths()
    if not mirror_active() or unit_ownership() is not True:
        return None
    try:
        value = json.loads(state_path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return None
    except (OSError, json.JSONDecodeError):
        return None
    if not isinstance(value, dict) or set(value) != {"source", "target", "unit"}:
        return None
    if value.get("unit") != UNIT or not all(isinstance(value.get(key), str) for key in ("source", "target")):
        return None
    return value


def remove_state() -> None:
    _, state_path, _ = runtime_paths()
    try:
        state_path.unlink()
    except FileNotFoundError:
        pass


def stop_owned(properties: dict[str, str] | None = None) -> bool:
    if properties is None:
        properties = unit_properties()
    ownership = unit_ownership(properties)
    if ownership is False:
        raise ownership_collision()
    was_active = mirror_active() if ownership is True else False
    if ownership is True:
        result = run([SYSTEMCTL, "--user", "stop", UNIT], check=False)
        if result.returncode not in (0, 3, 4, 5):
            detail = result.stderr.strip() or result.stdout.strip() or f"exit {result.returncode}"
            raise DisplayError(f"could not stop owned mirror: {detail}")
        run([SYSTEMCTL, "--user", "reset-failed", UNIT], check=False)
    remove_state()
    return was_active


def atomic_write_state(source: str, target: str) -> None:
    state_dir, state_path, _ = runtime_paths()
    state_dir.mkdir(mode=0o700, exist_ok=True)
    temporary = state_dir / f"mirror.json.tmp.{os.getpid()}"
    data = {"source": source, "target": target, "unit": UNIT}
    try:
        with temporary.open("x", encoding="utf-8") as handle:
            os.fchmod(handle.fileno(), 0o600)
            json.dump(data, handle, sort_keys=True)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, state_path)
    finally:
        try:
            temporary.unlink()
        except FileNotFoundError:
            pass


def choose_output(label: str, outputs: list[dict[str, Any]], *, exclude: str | None = None) -> str:
    choices = [output for output in outputs if output["active"] and output["name"] != exclude]
    if not choices:
        raise DisplayError(f"no active outputs available for {label.lower()}")
    if not sys.stdin.isatty() or not sys.stderr.isatty():
        raise DisplayError(f"{label.lower()} is required outside an interactive terminal; pass --{label.lower()}")
    focused = next((output for output in choices if output["focused"]), None)
    print(f"Select {label.lower()}:", file=sys.stderr)
    for index, output in enumerate(choices, 1):
        marker = " [focused default]" if output is focused else ""
        print(f"  {index}. {output['friendly']} ({output['name']}){marker}", file=sys.stderr)
    default_hint = f" (Enter confirms {focused['name']})" if focused else ""
    prompt = f"Selection{default_hint}: "
    response = input(prompt).strip()
    if not response and focused is not None:
        return focused["name"]
    if not response.isdigit() or not 1 <= int(response) <= len(choices):
        raise DisplayError("selection cancelled or invalid")
    return choices[int(response) - 1]["name"]


def command_outputs(args: argparse.Namespace) -> None:
    outputs = get_outputs()
    state = read_mirror_state()
    mirror = None if state is None else {**state, "active": True}
    if args.json:
        print(json.dumps({"version": 1, "outputs": outputs, "mirror": mirror}, sort_keys=True))
        return
    for output in outputs:
        flags = ", ".join(flag for flag, enabled in (("focused", output["focused"]), ("active", output["active"])) if enabled)
        current = output["current_mode"]
        if not output["active"]:
            mode = "disabled"
        elif current is None:
            mode = "mode unavailable"
        else:
            mode = f"{current['width']}x{current['height']}@{current['refresh_hz']} Hz"
        scale = "-" if output["logical"] is None else str(output["logical"]["scale"])
        print(f"{output['name']}: {output['friendly']} - {mode}, scale {scale}{f' [{flags}]' if flags else ''}")
    if mirror:
        print(f"Mirror: {mirror['source']} -> {mirror['target']} ({UNIT})")


def command_mirror(args: argparse.Namespace) -> None:
    require_expected_keys(args, "source", "target")
    initial_outputs = get_outputs() if args.source is None or args.target is None else []
    source_name = args.source or choose_output("Source", initial_outputs)
    source_for_choice = resolve_output(initial_outputs, source_name, active=True) if initial_outputs else None
    target_name = args.target or choose_output(
        "Target", initial_outputs, exclude=source_for_choice["name"] if source_for_choice else None
    )
    with locked():
        properties = unit_properties()
        ownership = unit_ownership(properties)
        if ownership is False:
            raise ownership_collision()
        outputs = get_outputs()
        source = resolve_action_output(outputs, source_name, action_key(args, "source"), "source", active=True)
        target = resolve_action_output(outputs, target_name, action_key(args, "target"), "target", active=True)
        if source["name"] == target["name"]:
            raise DisplayError("mirror source and target must be different outputs")
        if ownership is True and mirror_active():
            state = read_mirror_state()
            detail = ""
            if state:
                detail = f" ({state['source']} -> {state['target']})"
            raise DisplayError(f"an owned mirror is already active{detail}; stop it first")
        stop_owned(properties)
        command = [
            SYSTEMD_RUN,
            "--user",
            f"--unit={UNIT}",
            "--collect",
            "--service-type=exec",
            "--property=Restart=on-failure",
            "--property=RestartSec=1s",
            f"--property=Environment={UNIT_OWNER_MARKER}",
            f"--description={UNIT_DESCRIPTION}",
            WL_MIRROR,
            "--fullscreen-output",
            target["name"],
            source["name"],
        ]
        run(command)
        mirror_command = [WL_MIRROR, "--fullscreen-output", target["name"], source["name"]]
        confirm_started_unit(mirror_command)
        atomic_write_state(source["name"], target["name"])
    print(f"Mirroring {source['name']} to {target['name']}.")


def command_mirror_stop(_args: argparse.Namespace) -> None:
    with locked():
        stopped = stop_owned()
    print("Stopped owned mirror." if stopped else "No owned mirror was active.")


def command_extend(args: argparse.Namespace) -> None:
    with locked():
        # Mirror ownership comes from the unit, not state left by an older generation.
        properties = unit_properties()
        outputs = get_outputs()
        target = resolve_action_output(outputs, args.target, action_key(args, "target"), "target")
        stop_owned(properties)
        run([NIRI, "msg", "output", target["name"], "on"])
    print(f"Enabled {target['name']} without changing its mode or scale.")


def command_place(args: argparse.Namespace) -> None:
    require_expected_keys(args, "target", "reference")
    with locked():
        outputs = get_outputs()
        target = resolve_action_output(outputs, args.target, action_key(args, "target"), "target", active=True)
        reference = resolve_action_output(
            outputs, args.reference, action_key(args, "reference"), "reference", active=True
        )
        if target["name"] == reference["name"]:
            raise DisplayError("target and reference must be different outputs")
        target_rect = target["logical"]
        reference_rect = reference["logical"]
        if target_rect is None or reference_rect is None:
            raise DisplayError("both outputs must have unambiguous logical rectangles")
        if args.direction == "left-of":
            x, y = reference_rect["x"] - target_rect["width"], reference_rect["y"]
        elif args.direction == "right-of":
            x, y = reference_rect["x"] + reference_rect["width"], reference_rect["y"]
        elif args.direction == "above":
            x, y = reference_rect["x"], reference_rect["y"] - target_rect["height"]
        else:
            x, y = reference_rect["x"], reference_rect["y"] + reference_rect["height"]
        run([NIRI, "msg", "output", target["name"], "position", "set", str(x), str(y)])
    print(f"Placed {target['name']} {args.direction} {reference['name']} at {x},{y}.")


def canonical_scale(value: str) -> str:
    if value == "auto":
        return value
    if not SCALE_RE.fullmatch(value):
        raise DisplayError(f"invalid scale: {value}")
    number = decimal.Decimal(value)
    if not number.is_finite() or number <= 0 or number > 10:
        raise DisplayError("scale must be greater than 0 and no greater than 10")
    normalized = format(number.normalize(), "f")
    return normalized.rstrip("0").rstrip(".") if "." in normalized else normalized


def command_scale(args: argparse.Namespace) -> None:
    value = canonical_scale(args.scale)
    with locked():
        target = resolve_action_output(get_outputs(), args.target, action_key(args, "target"), "target", active=True)
        run([NIRI, "msg", "output", target["name"], "scale", value])
    print(f"Set {target['name']} scale to {value}.")


def select_mode(output: dict[str, Any], requested: str) -> str:
    if requested == "auto":
        return requested
    match = MODE_RE.fullmatch(requested)
    if match is None:
        raise DisplayError(f"invalid mode: {requested}")
    width, height = int(match.group("width")), int(match.group("height"))
    candidates = [
        mode for mode in output["modes"]
        if mode["width"] == width and mode["height"] == height
    ]
    if not candidates:
        raise DisplayError(f"no {width}x{height} mode for {output['name']}")
    hz = match.group("hz")
    if hz is None:
        selected = max(candidates, key=lambda mode: mode["refresh_mhz"])
    else:
        requested_mhz = hz_to_mhz(hz)
        exact = [mode for mode in candidates if mode["refresh_mhz"] == requested_mhz]
        if not exact:
            raise DisplayError(f"mode {requested} is not available on {output['name']}")
        selected = exact[0]
    return f"{width}x{height}@{format_mhz(selected['refresh_mhz'])}"


def command_mode(args: argparse.Namespace) -> None:
    with locked():
        target = resolve_action_output(get_outputs(), args.target, action_key(args, "target"), "target", active=True)
        mode = select_mode(target, args.mode)
        run([NIRI, "msg", "output", target["name"], "mode", mode])
    print(f"Set {target['name']} mode to {mode}.")


def command_menu(_args: argparse.Namespace) -> None:
    if not sys.stdin.isatty() or not sys.stderr.isatty():
        raise DisplayError("menu requires an interactive terminal")
    print("Display action:\n  1. Mirror\n  2. Stop mirror\n  3. Extend output\n  4. List outputs", file=sys.stderr)
    choice = input("Selection: ").strip()
    if choice == "1":
        command_mirror(argparse.Namespace(source=None, target=None))
    elif choice == "2":
        command_mirror_stop(argparse.Namespace())
    elif choice == "3":
        outputs = get_outputs()
        target = choose_output("Target", outputs)
        command_extend(argparse.Namespace(target=target))
    elif choice == "4":
        command_outputs(argparse.Namespace(json=False))
    else:
        raise DisplayError("selection cancelled or invalid")


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(
        prog="niri-display",
        description="Control niri output placement, mode, scale, and wl-mirror at runtime.",
    )
    commands = result.add_subparsers(dest="command", required=True)

    outputs = commands.add_parser("outputs", help="list connected outputs")
    outputs.add_argument("--json", action="store_true", help="emit the stable JSON document")
    outputs.set_defaults(function=command_outputs)

    mirror = commands.add_parser("mirror", help="mirror an active source onto an active target")
    mirror.add_argument("--source", help="source connector or unique make/model identity")
    mirror.add_argument("--target", help="target connector or unique make/model identity")
    mirror.add_argument("--source-key", help=argparse.SUPPRESS)
    mirror.add_argument("--target-key", help=argparse.SUPPRESS)
    mirror.set_defaults(function=command_mirror)

    mirror_stop = commands.add_parser("mirror-stop", help="stop the owned mirror if it is active")
    mirror_stop.set_defaults(function=command_mirror_stop)

    extend = commands.add_parser("extend", help="stop the owned mirror and enable TARGET")
    extend.add_argument("target")
    extend.add_argument("--target-key", help=argparse.SUPPRESS)
    extend.set_defaults(function=command_extend)

    place = commands.add_parser("place", help="place TARGET adjacent to REFERENCE")
    place.add_argument("target")
    place.add_argument("direction", choices=("left-of", "right-of", "above", "below"))
    place.add_argument("reference")
    place.add_argument("--target-key", help=argparse.SUPPRESS)
    place.add_argument("--reference-key", help=argparse.SUPPRESS)
    place.set_defaults(function=command_place)

    scale = commands.add_parser("scale", help="set runtime output scale")
    scale.add_argument("target")
    scale.add_argument("scale", help="auto or a positive numeric scale")
    scale.add_argument("--target-key", help=argparse.SUPPRESS)
    scale.set_defaults(function=command_scale)

    mode = commands.add_parser("mode", help="set runtime output mode")
    mode.add_argument("target")
    mode.add_argument("mode", help="auto, WIDTHxHEIGHT, or WIDTHxHEIGHT@HZ")
    mode.add_argument("--target-key", help=argparse.SUPPRESS)
    mode.set_defaults(function=command_mode)

    menu = commands.add_parser("menu", help="open an interactive terminal menu")
    menu.set_defaults(function=command_menu)
    return result


def main(argv: list[str] | None = None) -> int:
    try:
        args = parser().parse_args(argv)
        args.function(args)
        return 0
    except DisplayError as exc:
        print(f"niri-display: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
