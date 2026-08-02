#!/usr/bin/env python3
import json
import unittest
from pathlib import Path


PLUGIN_ROOT = Path(__file__).parent / "plugins"


class PluginAssetsTest(unittest.TestCase):
    def test_plugin_assets_and_manifest_entry_points(self) -> None:
        expected_files = {
            "niri-display": {
                "BarWidget.qml",
                "DisplayState.js",
                "Main.qml",
                "Panel.qml",
                "manifest.json",
            },
            "voxtype": {"BarWidget.qml", "Main.qml", "manifest.json"},
        }
        for plugin, files in expected_files.items():
            root = PLUGIN_ROOT / plugin
            self.assertEqual({path.name for path in root.iterdir()}, files)
            manifest = json.loads((root / "manifest.json").read_text())
            self.assertEqual(manifest["id"], plugin)
            for entry_point in manifest["entryPoints"].values():
                self.assertIn(entry_point, files)


if __name__ == "__main__":
    unittest.main()
