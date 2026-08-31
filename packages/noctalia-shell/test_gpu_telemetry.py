#!/usr/bin/env python3
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path


TELEMETRY_SOURCE = Path(sys.argv[1])


class GpuTelemetryTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        source = TELEMETRY_SOURCE.read_text()
        match = re.search(
            r"readonly property string gpuUsageCommand: `\n(.*?)\n  `", source, re.DOTALL
        )
        if match is None:
            raise AssertionError("could not extract gpuUsageCommand")
        # QML turns \${ into a literal shell ${ in a template string.
        cls.command = match.group(1).replace(r"\${", "${")
        cls.source = source

    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.drm = self.root / "drm"
        self.drm.mkdir()
        self.fixture = self.root / "nvtop.json"
        self.invocations = self.root / "nvtop-invocations"
        self.nvidia_invocations = self.root / "nvidia-invocations"
        self.nvtop = self.root / "nvtop"
        self.nvidia_smi = self.root / "nvidia-smi"
        self.nvtop.write_text(
            "#!/bin/sh\nprintf x >> \"$NOCTALIA_NVTOP_INVOCATIONS\"\n"
            "cat \"$NOCTALIA_NVTOP_FIXTURE\"\n"
        )
        self.nvidia_smi.write_text(
            "#!/bin/sh\nprintf x >> \"$NOCTALIA_NVIDIA_INVOCATIONS\"\n"
            "printf '67\\n'\n"
        )
        self.nvtop.chmod(0o755)
        self.nvidia_smi.chmod(0o755)

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def card(
        self,
        number,
        vendor,
        *,
        boot_vga=None,
        status="active",
        busy=None,
        vram=None,
    ) -> None:
        device = self.drm / f"card{number}" / "device"
        (device / "power").mkdir(parents=True)
        (device / "vendor").write_text(vendor)
        if boot_vga is not None:
            (device / "boot_vga").write_text(f"{boot_vga}\n")
        (device / "power" / "runtime_status").write_text(status)
        if busy is not None:
            (device / "gpu_busy_percent").write_text(f"{busy}\n")
        if vram is not None:
            (device / "mem_info_vram_total").write_text(f"{vram}\n")

    def run_probe(self, enabled=False, bounded=False):
        environment = os.environ | {
            "NOCTALIA_DRM_ROOT": str(self.drm),
            "NOCTALIA_INTEL_NVTOP": str(self.nvtop),
            "NOCTALIA_NVIDIA_SMI": str(self.nvidia_smi),
            "NOCTALIA_NVTOP_FIXTURE": str(self.fixture),
            "NOCTALIA_NVTOP_INVOCATIONS": str(self.invocations),
            "NOCTALIA_NVIDIA_INVOCATIONS": str(self.nvidia_invocations),
        }
        command = ["sh", "-c", self.command, "gpu-usage", "1" if enabled else "0"]
        if bounded:
            timeout = re.search(r'"([^\"]*/bin/timeout)", "-k", "1", "3"', self.source)
            self.assertIsNotNone(timeout)
            command = [timeout.group(1), "-k", "1", "3"] + command
        return subprocess.run(command, env=environment, text=True, capture_output=True)

    def test_nvtop_json_fixtures(self) -> None:
        self.card(0, "0x8086")
        cases = [
            ('{"gpu_util": "42%"}', 0, "42"),
            ('[{"gpu_util": "13%"}, {"gpu_util": "91.4%"}]', 0, "91"),
            ('{"gpu_util": null}', 0, "unavailable"),
            ('{"gpu_util": "not-a-number"}', 0, "unavailable"),
            ('{"gpu_util": "42%"', 1, ""),
        ]
        for payload, returncode, output in cases:
            with self.subTest(payload=payload):
                self.fixture.write_text(payload)
                result = self.run_probe(enabled=True)
                self.assertEqual(result.returncode, returncode)
                self.assertEqual(result.stdout.strip(), output)

    def test_vendor_gating_ignores_boot_vga_and_never_runs_global_tools_without_opt_in(self) -> None:
        self.fixture.write_text('{"gpu_util": "42%"}')

        # A discrete AMD boot adapter has boot_vga=1. Dedicated VRAM, not
        # boot_vga, is Noctalia v4's dGPU signal.
        self.card(0, "0x1002", boot_vga=1, busy=77, vram=8_589_934_592)
        self.assertEqual(self.run_probe(enabled=False).stdout.strip(), "unavailable")
        self.assertEqual(self.run_probe(enabled=True).stdout.strip(), "77")

        shutil.rmtree(self.drm)
        self.drm.mkdir()
        # An AMD iGPU normally has no boot_vga file and no dedicated VRAM.
        self.card(0, "0x1002", busy=23, vram=0)
        self.assertEqual(self.run_probe(enabled=False).stdout.strip(), "23")

        shutil.rmtree(self.drm)
        self.drm.mkdir()
        # Intel xe/Arc is discrete in Noctalia v4 even when boot_vga is absent.
        self.card(0, "0x8086")
        self.assertEqual(self.run_probe(enabled=False).stdout.strip(), "unavailable")
        self.assertFalse(self.invocations.exists(), "Intel dGPU ran global nvtop without opt-in")
        self.assertEqual(self.run_probe(enabled=True).stdout.strip(), "42")

        shutil.rmtree(self.drm)
        self.drm.mkdir()
        # A mixed active+suspended NVIDIA setup alongside an AMD iGPU must not
        # cause the global nvidia-smi query when dGPU monitoring is disabled.
        self.card(0, "0x1002", busy=31, vram=0)
        self.card(1, "0x10de", boot_vga=1, status="suspended")
        self.card(2, "0x10de", status="active")
        self.assertEqual(self.run_probe(enabled=False).stdout.strip(), "31")
        self.assertFalse(self.nvidia_invocations.exists(), "suspended NVIDIA dGPU ran nvidia-smi")

        shutil.rmtree(self.drm)
        self.drm.mkdir()
        self.invocations.unlink()
        # A suspended Intel card blocks nvtop even if another Intel card is active.
        self.card(0, "0x8086", status="active")
        self.card(1, "0x8086", boot_vga=1, status="suspended")
        self.assertEqual(self.run_probe(enabled=True).stdout.strip(), "unavailable")
        self.assertFalse(self.invocations.exists(), "suspended Intel dGPU woke nvtop")

    def test_probe_timeout_and_stop_cleanup_are_declared(self) -> None:
        self.card(0, "0x8086")
        self.nvtop.write_text("#!/bin/sh\nsleep 10\n")
        self.nvtop.chmod(0o755)
        started = time.monotonic()
        result = self.run_probe(enabled=True, bounded=True)
        self.assertLess(time.monotonic() - started, 5)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.source.count("onShouldRunChanged:"), 1)
        self.assertIn("gpuUsageProcess.signal(15)", self.source)
        self.assertIn("id: gpuUsageWatchdog", self.source)
        self.assertIn("gpuUsageProcess.signal(9)", self.source)
        self.assertIn("/bin/nvidia-smi", self.source)
        self.assertIn("/bin/awk", self.source)


if __name__ == "__main__":
    sys.argv = sys.argv[:1]
    unittest.main()
