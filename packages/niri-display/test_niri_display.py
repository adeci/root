from __future__ import annotations

import argparse
import contextlib
import importlib.util
import json
import os
import stat
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
from pathlib import Path

MODULE_PATH = Path(__file__).with_name("niri_display.py")
STORE_HASH = "0123456789abcdfghijklmnpqrsvwxyz"
OLD_STORE_HASH = "11111111111111111111111111111111"
STORE_WL_MIRROR = f"/nix/store/{STORE_HASH}-wl-mirror-0.17.0/bin/wl-mirror"

spec = importlib.util.spec_from_file_location("niri_display", MODULE_PATH)
assert spec and spec.loader
nd = importlib.util.module_from_spec(spec)
spec.loader.exec_module(nd)


def mode(width=1920, height=1080, refresh=60000, preferred=False):
    return {
        "width": width,
        "height": height,
        "refresh_rate": refresh,
        "is_preferred": preferred,
    }


def output(
    name,
    *,
    make="Acme",
    model="Panel",
    serial=None,
    active=True,
    x=0,
    y=0,
    width=1920,
    height=1080,
    scale=1,
    transform="Normal",
    modes=None,
    current=0,
):
    available = modes or [mode()]
    return {
        "name": name,
        "make": make,
        "model": model,
        "serial": serial,
        "modes": available,
        "current_mode": current if active else None,
        "logical": {
            "x": x,
            "y": y,
            "width": width,
            "height": height,
            "scale": scale,
            "transform": transform,
        }
        if active
        else None,
    }


class ParsingTests(unittest.TestCase):
    def test_output_identity_and_active_state(self):
        raw = {
            "DP-1": output(
                "DP-1", make="Same", model="Model", serial="one", current=None
            ),
            "DP-2": output("DP-2", make="Same", model="Model", serial="two"),
            "HDMI-A-1": output("HDMI-A-1", active=False),
        }
        outputs = nd.normalize_outputs(raw, "DP-1")

        dp1 = nd.resolve_output(outputs, "Same Model one", active=True)
        self.assertTrue(dp1["focused"])
        self.assertTrue(dp1["active"])
        self.assertIsNone(dp1["current_mode"])
        self.assertEqual(
            dp1["selection_key"],
            '{"connector":"DP-1","make":"Same","model":"Model","serial":"one"}',
        )
        with self.assertRaisesRegex(nd.DisplayError, "ambiguous"):
            nd.resolve_output(outputs, "Same Model")
        with self.assertRaisesRegex(nd.DisplayError, "not found"):
            nd.resolve_output(outputs, "missing")
        with self.assertRaisesRegex(nd.DisplayError, "not active"):
            nd.resolve_output(outputs, "HDMI-A-1", active=True)

    def test_selection_key_is_canonical_and_unambiguous(self):
        self.assertEqual(
            nd.selection_key("DP-1", "Same", "Model", "one"),
            '{"connector":"DP-1","make":"Same","model":"Model","serial":"one"}',
        )
        self.assertNotEqual(
            nd.selection_key("DP-1", "A", "B|C", None),
            nd.selection_key("DP-1", "A|B", "C", None),
        )

    def test_exact_refresh_and_mode_selection(self):
        parsed = nd.normalize_outputs(
            {
                "DP-1": output(
                    "DP-1",
                    modes=[
                        mode(2560, 1440, 59951),
                        mode(2560, 1440, 144000),
                        mode(1920, 1080, 60000),
                    ],
                )
            },
            None,
        )[0]

        self.assertEqual(nd.format_mhz(59951), "59.951")
        self.assertEqual(nd.hz_to_mhz("59.951"), 59951)
        self.assertEqual(nd.select_mode(parsed, "auto"), "auto")
        self.assertEqual(nd.select_mode(parsed, "2560x1440"), "2560x1440@144")
        self.assertEqual(
            nd.select_mode(parsed, "2560x1440@59.951"), "2560x1440@59.951"
        )
        with self.assertRaises(nd.DisplayError):
            nd.hz_to_mhz("59.9511")
        with self.assertRaisesRegex(nd.DisplayError, "not available"):
            nd.select_mode(parsed, "2560x1440@60")

    def test_scale_validation(self):
        self.assertEqual(nd.canonical_scale("auto"), "auto")
        self.assertEqual(nd.canonical_scale("2.00"), "2")
        self.assertEqual(nd.canonical_scale("1.25"), "1.25")
        for value in ("0", "-1", "nan", "11"):
            with self.subTest(value=value), self.assertRaises(nd.DisplayError):
                nd.canonical_scale(value)

    def test_owned_command_paths(self):
        def exec_start(path, argv=None):
            argv = argv or [path, "--fullscreen-output", "DP-2", "eDP-1"]
            return f"{{ path={path} ; argv[]={' '.join(argv)} ; ignore_errors=no ; }}"

        old = f"/nix/store/{OLD_STORE_HASH}-wl-mirror-0.16.0/bin/wl-mirror"
        self.assertTrue(nd.is_mirror_command(exec_start(STORE_WL_MIRROR)))
        self.assertTrue(nd.is_mirror_command(exec_start(old)))
        self.assertFalse(nd.is_mirror_command(exec_start("/tmp/wl-mirror")))
        self.assertFalse(
            nd.is_mirror_command(
                exec_start(
                    STORE_WL_MIRROR,
                    ["/bin/sh", "-c", f"{STORE_WL_MIRROR} --fullscreen-output DP-2 eDP-1"],
                )
            )
        )


FAKE_PROGRAM = r'''#!@python@
import json, os, pathlib, sys
runtime = pathlib.Path(os.environ["XDG_RUNTIME_DIR"])
name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
with (runtime / "commands.jsonl").open("a") as handle:
    handle.write(json.dumps([name] + args) + "\n")
unit_path = runtime / "fake-unit.json"

def read_unit():
    return json.loads(unit_path.read_text()) if unit_path.exists() else None

if name == "niri":
    if args == ["msg", "--json", "outputs"]:
        print(pathlib.Path(os.environ["FAKE_OUTPUTS"]).read_text(), end="")
    elif args == ["msg", "--json", "focused-output"]:
        focused = os.environ.get("FAKE_FOCUSED", "")
        print("null" if not focused else json.dumps({"name": focused}))
elif name == "systemctl":
    unit = read_unit()
    if args[1:3] == ["is-active", "--quiet"]:
        sys.exit(0 if unit and unit["ActiveState"] == "active" else 3)
    if args[1] == "show":
        properties = [arg.split("=", 1)[1] for arg in args if arg.startswith("--property=")]
        if unit is None:
            if not os.environ.get("FAKE_SYSTEMD_SHOW_MISSING_SUCCESS"):
                sys.exit(4)
            unit = {
                "LoadState": "not-found",
                "Transient": "no",
                "Description": "niri-display-mirror.service",
                "ActiveState": "inactive",
                "SubState": "dead",
            }
        for prop in properties:
            print(f"{prop}={unit.get(prop, '')}")
    elif args[1] == "status":
        if unit is None:
            sys.exit(4)
        print("fake systemctl status: wl-mirror exited immediately")
        sys.exit(3 if unit["ActiveState"] == "failed" else 0)
    elif args[1] == "stop":
        unit_path.unlink(missing_ok=True)
    elif args[1] == "reset-failed":
        pass
    else:
        sys.exit(64)
elif name == "systemd-run":
    description = next(arg.split("=", 1)[1] for arg in args if arg.startswith("--description="))
    owner = next(arg[len("--property=Environment="):] for arg in args
                 if arg.startswith("--property=Environment="))
    command_index = next(i for i, arg in enumerate(args) if not arg.startswith("--"))
    command = args[command_index:]
    failed = bool(os.environ.get("FAKE_WL_MIRROR_IMMEDIATE_FAIL"))
    exec_start = "{ path=" + command[0] + " ; argv[]=" + " ".join(command) + " ; ignore_errors=no ; }"
    if os.environ.get("FAKE_SYSTEMD_261_EXECSTART"):
        exec_start = (
            "{ path=" + command[0] + " ; argv[]=" + " ".join(command)
            + " ; ignore_errors=no ; start_time=[Sun 2026-08-02 03:42:34 EDT] ; "
            "stop_time=[n/a] ; pid=548554 ; code=(null) ; status=0/0 }"
        )
    unit_path.write_text(json.dumps({
        "LoadState": "loaded",
        "Transient": "yes",
        "Environment": owner,
        "Description": description,
        "ExecStart": exec_start,
        "ActiveState": "failed" if failed else "active",
        "SubState": "failed" if failed else "running",
        "Result": "exit-code" if failed else "success",
        "ExecMainCode": "exited" if failed else "0",
        "ExecMainStatus": "23" if failed else "0",
    }))
else:
    sys.exit(64)
'''


class CommandTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.runtime = self.root / "runtime"
        self.bin = self.root / "fake-bin"
        self.runtime.mkdir()
        self.bin.mkdir()

        fake = self.bin / "fake"
        fake.write_text(FAKE_PROGRAM.replace("@python@", sys.executable))
        fake.chmod(fake.stat().st_mode | stat.S_IXUSR)
        for name in ("niri", "systemctl", "systemd-run"):
            (self.bin / name).symlink_to(fake)

        self.outputs_file = self.runtime / "outputs.json"
        self.outputs_file.write_text(
            json.dumps(
                {
                    "eDP-1": output(
                        "eDP-1",
                        make="Laptop",
                        model="LCD",
                        current=None,
                        x=-800,
                        y=200,
                        width=800,
                        height=1280,
                        scale=2,
                        transform="270",
                        modes=[mode(2560, 1600, 143999), mode(2560, 1600, 60000)],
                    ),
                    "DP-2": output(
                        "DP-2",
                        make="Projector",
                        model="Beam",
                        x=300,
                        y=-400,
                        modes=[mode(1920, 1080, 59951), mode(1920, 1080, 60000)],
                    ),
                    "HDMI-A-1": output("HDMI-A-1", active=False),
                }
            )
        )
        self.env = os.environ.copy()
        self.env.update(
            {
                "PATH": "",
                "HOME": str(self.root / "home"),
                "XDG_RUNTIME_DIR": str(self.runtime),
                "FAKE_OUTPUTS": str(self.outputs_file),
                "FAKE_FOCUSED": "eDP-1",
                "NIRI_DISPLAY_NIRI": str(self.bin / "niri"),
                "NIRI_DISPLAY_SYSTEMCTL": str(self.bin / "systemctl"),
                "NIRI_DISPLAY_SYSTEMD_RUN": str(self.bin / "systemd-run"),
                "NIRI_DISPLAY_WL_MIRROR": STORE_WL_MIRROR,
            }
        )

    def tearDown(self):
        self.temp.cleanup()

    def call(self, *args, success=True, extra_env=None):
        env = dict(self.env)
        env.update(extra_env or {})
        result = subprocess.run(
            [sys.executable, str(MODULE_PATH), *args],
            env=env,
            text=True,
            capture_output=True,
            check=False,
        )
        if success and result.returncode != 0:
            self.fail(f"command failed: {args}\n{result.stderr}")
        if not success and result.returncode == 0:
            self.fail(f"command unexpectedly succeeded: {args}")
        return result

    def set_outputs(self, outputs):
        self.outputs_file.write_text(json.dumps(outputs))

    def output_key(self, connector):
        value = json.loads(self.call("outputs", "--json").stdout)
        return next(item["selection_key"] for item in value["outputs"] if item["name"] == connector)

    def commands(self):
        path = self.runtime / "commands.jsonl"
        return [] if not path.exists() else [json.loads(line) for line in path.read_text().splitlines()]

    def mutations_since(self, baseline):
        return [
            command
            for command in self.commands()[baseline:]
            if command[0] == "systemd-run"
            or command[:3] in (
                ["systemctl", "--user", "stop"],
                ["systemctl", "--user", "reset-failed"],
                ["niri", "msg", "output"],
            )
        ]

    def write_unit(
        self,
        *,
        path=STORE_WL_MIRROR,
        marker=nd.UNIT_OWNER_MARKER,
        active="inactive",
        result="success",
    ):
        self.runtime.joinpath("fake-unit.json").write_text(
            json.dumps(
                {
                    "LoadState": "loaded",
                    "Transient": "yes",
                    "Environment": marker,
                    "Description": nd.UNIT_DESCRIPTION,
                    "ExecStart": f"{{ path={path} ; argv[]={path} --fullscreen-output DP-2 eDP-1 ; ignore_errors=no ; }}",
                    "ActiveState": active,
                    "SubState": "running" if active == "active" else "dead",
                    "Result": result,
                    "ExecMainCode": "0" if result == "success" else "exited",
                    "ExecMainStatus": "0" if result == "success" else "23",
                }
            )
        )

    def test_outputs_json_contract(self):
        value = json.loads(self.call("outputs", "--json").stdout)
        self.assertEqual(value["version"], 1)
        self.assertEqual([item["name"] for item in value["outputs"]], ["DP-2", "HDMI-A-1", "eDP-1"])
        laptop = next(item for item in value["outputs"] if item["name"] == "eDP-1")
        self.assertTrue(laptop["active"])
        self.assertTrue(laptop["focused"])
        self.assertIsNone(laptop["current_mode"])

    def test_mirror_order_state_and_single_active_unit(self):
        self.call("mirror", "--source", "eDP-1", "--target", "DP-2")
        start = next(command for command in self.commands() if command[0] == "systemd-run")
        self.assertEqual(start[-4:], [STORE_WL_MIRROR, "--fullscreen-output", "DP-2", "eDP-1"])
        state = json.loads((self.runtime / "niri-display" / "mirror.json").read_text())
        self.assertEqual((state["source"], state["target"]), ("eDP-1", "DP-2"))

        baseline = len(self.commands())
        self.call("mirror", "--source", "DP-2", "--target", "eDP-1", success=False)
        self.assertEqual(self.mutations_since(baseline), [])

    def test_systemd_261_exec_start_keeps_owned_mirror_active(self):
        result = self.call(
            "mirror",
            "--source",
            "eDP-1",
            "--target",
            "DP-2",
            extra_env={"FAKE_SYSTEMD_261_EXECSTART": "1"},
        )
        self.assertIn("Mirroring eDP-1 to DP-2.", result.stdout)
        self.assertNotIn("not owned", result.stderr)
        state = json.loads((self.runtime / "niri-display" / "mirror.json").read_text())
        self.assertEqual((state["source"], state["target"]), ("eDP-1", "DP-2"))
        active = json.loads(self.call("outputs", "--json").stdout)
        self.assertEqual(active["mirror"], {**state, "active": True})
        self.assertTrue((self.runtime / "fake-unit.json").exists())
        self.assertFalse(any(command[:3] == ["systemctl", "--user", "stop"] for command in self.commands()))

    def test_expected_keys_reject_replaced_or_missing_outputs_before_mutation(self):
        initial = {
            "DP-1": output("DP-1", make="VITURE", model="Pro", serial="A"),
            "DP-2": output("DP-2", make="Projector", model="Beam", serial="two"),
        }
        self.env["FAKE_FOCUSED"] = "DP-1"
        self.set_outputs(initial)
        old_source_key = self.output_key("DP-1")
        target_key = self.output_key("DP-2")

        self.set_outputs({
            "DP-1": output("DP-1", make="MSI", model="MAG", serial="B"),
            "DP-2": initial["DP-2"],
        })
        baseline = len(self.commands())
        result = self.call(
            "mirror", "--source", "DP-1", "--source-key", old_source_key,
            "--target", "DP-2", "--target-key", target_key, success=False,
        )
        self.assertIn("source selection no longer matches", result.stderr)
        self.assertEqual(self.mutations_since(baseline), [])

        new_source_key = self.output_key("DP-1")
        self.call(
            "mirror", "--source", "DP-1", "--source-key", new_source_key,
            "--target", "DP-2", "--target-key", target_key,
        )

        self.call("mirror-stop")
        self.env["FAKE_FOCUSED"] = "DP-2"
        self.set_outputs({"DP-2": initial["DP-2"]})
        baseline = len(self.commands())
        result = self.call(
            "mirror", "--source", "DP-1", "--source-key", new_source_key,
            "--target", "DP-2", "--target-key", target_key, success=False,
        )
        self.assertIn("output not found", result.stderr)
        self.assertEqual(self.mutations_since(baseline), [])

    def test_expected_keys_validate_both_sides_and_disabled_targets(self):
        source_key = self.output_key("eDP-1")
        target_key = self.output_key("DP-2")
        disabled_key = self.output_key("HDMI-A-1")

        self.set_outputs({
            "eDP-1": output("eDP-1", make="Laptop", model="LCD"),
            "DP-2": output("DP-2", make="Replacement", model="Beam"),
            "HDMI-A-1": output("HDMI-A-1", active=False),
        })
        baseline = len(self.commands())
        result = self.call(
            "mirror", "--source", "eDP-1", "--source-key", source_key,
            "--target", "DP-2", "--target-key", target_key, success=False,
        )
        self.assertIn("target selection no longer matches", result.stderr)
        self.assertEqual(self.mutations_since(baseline), [])

        baseline = len(self.commands())
        result = self.call(
            "extend", "HDMI-A-1", "--target-key", "not-a-selection-key", success=False,
        )
        self.assertIn("invalid target selection key", result.stderr)
        self.assertEqual(self.mutations_since(baseline), [])

        self.call("extend", "HDMI-A-1", "--target-key", disabled_key)
        self.assertIn(["niri", "msg", "output", "HDMI-A-1", "on"], self.mutations_since(baseline))

        baseline = len(self.commands())
        self.call(
            "mirror", "--source", "eDP-1", "--source-key", source_key,
            "--target", "HDMI-A-1", "--target-key", disabled_key, success=False,
        )
        self.assertEqual(self.mutations_since(baseline), [])

    def test_expected_keys_cover_place_scale_and_mode(self):
        source_key = self.output_key("eDP-1")
        target_key = self.output_key("DP-2")
        self.set_outputs({
            "eDP-1": output("eDP-1", make="Laptop", model="LCD"),
            "DP-2": output("DP-2", make="Replacement", model="Beam"),
            "HDMI-A-1": output("HDMI-A-1", active=False),
        })
        commands = (
            ("place", "DP-2", "left-of", "eDP-1", "--target-key", target_key,
             "--reference-key", source_key),
            ("scale", "DP-2", "1.25", "--target-key", target_key),
            ("mode", "DP-2", "1920x1080", "--target-key", target_key),
        )
        for command in commands:
            with self.subTest(command=command):
                baseline = len(self.commands())
                result = self.call(*command, success=False)
                self.assertIn("target selection no longer matches", result.stderr)
                self.assertEqual(self.mutations_since(baseline), [])

    def test_expected_key_validation_rejects_duplicate_key_before_mutation(self):
        outputs = nd.normalize_outputs({"DP-1": output("DP-1", serial="one")}, None)
        duplicate = dict(outputs[0])
        duplicate["name"] = "DP-2"
        with self.assertRaisesRegex(nd.DisplayError, "ambiguous source selection key"):
            nd.resolve_action_output(outputs + [duplicate], "DP-1", outputs[0]["selection_key"], "source")

        with (
            mock.patch.object(nd, "locked", return_value=contextlib.nullcontext()),
            mock.patch.object(nd, "unit_properties", return_value=None),
            mock.patch.object(nd, "get_outputs", return_value=outputs + [duplicate]),
            mock.patch.object(nd, "run") as run,
            self.assertRaisesRegex(nd.DisplayError, "ambiguous target selection key"),
        ):
            nd.command_extend(argparse.Namespace(target="DP-1", target_key=outputs[0]["selection_key"]))
        run.assert_not_called()

    def test_menu_dispatches_keyless_mirror_and_extend(self):
        outputs = nd.normalize_outputs(
            {
                "eDP-1": output("eDP-1", make="Laptop", model="LCD"),
                "DP-2": output("DP-2", make="Projector", model="Beam"),
            },
            "eDP-1",
        )
        stdin = mock.Mock()
        stderr = mock.Mock()
        stdin.isatty.return_value = True
        stderr.isatty.return_value = True
        commands = []

        def record_run(command, *, check=True):
            commands.append(command)
            return subprocess.CompletedProcess(command, 0, "", "")

        common = (
            mock.patch.object(nd, "get_outputs", return_value=outputs),
            mock.patch.object(nd, "locked", return_value=contextlib.nullcontext()),
            mock.patch.object(nd, "unit_properties", return_value=None),
            mock.patch.object(nd, "unit_ownership", return_value=None),
            mock.patch.object(nd, "stop_owned"),
            mock.patch.object(nd, "confirm_started_unit"),
            mock.patch.object(nd, "atomic_write_state"),
            mock.patch.object(nd, "run", side_effect=record_run),
            mock.patch.object(nd.sys, "stdin", stdin),
            mock.patch.object(nd.sys, "stderr", stderr),
        )
        with contextlib.ExitStack() as stack:
            for patch in common:
                stack.enter_context(patch)
            with mock.patch("builtins.input", return_value="1"), mock.patch.object(
                nd, "choose_output", side_effect=["eDP-1", "DP-2"]
            ):
                nd.command_menu(argparse.Namespace())
            with mock.patch("builtins.input", return_value="3"), mock.patch.object(
                nd, "choose_output", return_value="DP-2"
            ):
                nd.command_menu(argparse.Namespace())

        self.assertTrue(any(command[0] == nd.SYSTEMD_RUN for command in commands))
        self.assertIn([nd.NIRI, "msg", "output", "DP-2", "on"], commands)

    def test_mirror_rejects_bad_source_target_pairs(self):
        commands = (
            ("mirror", "--source", "DP-2", "--target", "DP-2"),
            ("mirror", "--source", "missing", "--target", "DP-2"),
            ("mirror", "--source", "HDMI-A-1", "--target", "DP-2"),
        )
        for command in commands:
            with self.subTest(command=command):
                baseline = len(self.commands())
                self.call(*command, success=False)
                self.assertEqual(self.mutations_since(baseline), [])

    def test_stop_is_idempotent_for_an_absent_unit(self):
        state_dir = self.runtime / "niri-display"
        state_dir.mkdir()
        (state_dir / "mirror.json").write_text('{"stale":true}')
        env = {"FAKE_SYSTEMD_SHOW_MISSING_SUCCESS": "1"}

        self.call("mirror-stop", extra_env=env)
        self.call("mirror-stop", extra_env=env)
        self.assertFalse((state_dir / "mirror.json").exists())
        self.assertEqual(self.mutations_since(0), [])

    def test_old_store_generations_remain_owned(self):
        old_path = f"/nix/store/{OLD_STORE_HASH}-wl-mirror-0.16.0/bin/wl-mirror"
        self.write_unit(path=old_path, active="failed", result="exit-code")
        self.call("mirror", "--source", "eDP-1", "--target", "DP-2")
        self.assertTrue(any(command[:3] == ["systemctl", "--user", "stop"] for command in self.commands()))

        legacy_path = f"/nix/store/{OLD_STORE_HASH}-wl-mirror-0.15.0/bin/wl-mirror"
        self.write_unit(path=legacy_path, marker="")
        self.call("extend", "HDMI-A-1")
        self.assertFalse((self.runtime / "fake-unit.json").exists())

    def test_foreign_unit_is_never_mutated(self):
        unit = {
            "LoadState": "loaded",
            "Transient": "yes",
            "Environment": nd.UNIT_OWNER_MARKER,
            "Description": nd.UNIT_DESCRIPTION,
            "ExecStart": "{ path=/foreign ; argv[]=/foreign --fullscreen-output DP-2 eDP-1 ; ignore_errors=no ; }",
            "ActiveState": "active",
            "SubState": "running",
            "Result": "success",
            "ExecMainCode": "0",
            "ExecMainStatus": "0",
        }
        commands = (
            ("mirror", "--source", "eDP-1", "--target", "DP-2"),
            ("mirror-stop",),
            ("extend", "HDMI-A-1"),
        )
        for command in commands:
            with self.subTest(command=command):
                unit_path = self.runtime / "fake-unit.json"
                unit_path.write_text(json.dumps(unit))
                baseline = len(self.commands())
                result = self.call(*command, success=False)
                self.assertIn("not owned", result.stderr)
                self.assertEqual(json.loads(unit_path.read_text()), unit)
                self.assertEqual(self.mutations_since(baseline), [])

    def test_immediate_start_failure_is_cleaned_up(self):
        result = self.call(
            "mirror",
            "--source",
            "eDP-1",
            "--target",
            "DP-2",
            success=False,
            extra_env={"FAKE_WL_MIRROR_IMMEDIATE_FAIL": "1"},
        )
        self.assertIn("ExecMainStatus=23", result.stderr)
        self.assertNotIn("Mirroring ", result.stdout)
        self.assertFalse((self.runtime / "fake-unit.json").exists())
        self.assertFalse((self.runtime / "niri-display" / "mirror.json").exists())

    def test_extend_stops_mirror_without_changing_mode_or_scale(self):
        self.call("mirror", "--source", "eDP-1", "--target", "DP-2")
        baseline = len(self.commands())
        self.call("extend", "DP-2")
        mutations = self.mutations_since(baseline)
        self.assertIn(["niri", "msg", "output", "DP-2", "on"], mutations)
        self.assertFalse(any("mode" in command or "scale" in command for command in mutations))

    def test_place_uses_logical_rectangles(self):
        expected = {
            "left-of": (-500, -400),
            "right-of": (2220, -400),
            "above": (300, -1680),
            "below": (300, 680),
        }
        for direction, (x, y) in expected.items():
            with self.subTest(direction=direction):
                baseline = len(self.commands())
                self.call("place", "eDP-1", direction, "DP-2")
                self.assertIn(
                    ["niri", "msg", "output", "eDP-1", "position", "set", str(x), str(y)],
                    self.mutations_since(baseline),
                )

    def test_scale_and_mode_issue_exact_ipc(self):
        self.call("scale", "eDP-1", "1.25")
        self.call("mode", "DP-2", "1920x1080")
        self.call("mode", "DP-2", "1920x1080@59.951")
        mutations = self.mutations_since(0)
        self.assertIn(["niri", "msg", "output", "eDP-1", "scale", "1.25"], mutations)
        self.assertIn(["niri", "msg", "output", "DP-2", "mode", "1920x1080@60"], mutations)
        self.assertIn(["niri", "msg", "output", "DP-2", "mode", "1920x1080@59.951"], mutations)


if __name__ == "__main__":
    unittest.main()
