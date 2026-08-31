#!/usr/bin/env python3
import json
import unittest
from pathlib import Path


PACKAGE_ROOT = Path(__file__).parent
PLUGIN_ROOT = PACKAGE_ROOT / "plugins"


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

        vendored_files = {
            "mullvad": {
                "BarWidget.qml",
                "Main.qml",
                "MullvadIcon.qml",
                "Panel.qml",
                "README.md",
                "mullvad.svg",
                "Settings.qml",
                "i18n/en.json",
                "manifest.json",
            },
            "tailscale": {
                "BarWidget.qml",
                "Main.qml",
                "Panel.qml",
                "PeerState.js",
                "README.md",
                "Settings.qml",
                "TailscaleIcon.qml",
                "i18n/en.json",
                "manifest.json",
            },
        }
        for plugin, files in vendored_files.items():
            root = PLUGIN_ROOT / plugin
            actual_files = {
                str(path.relative_to(root)) for path in root.rglob("*") if path.is_file()
            }
            self.assertEqual(actual_files, files)
            manifest = json.loads((root / "manifest.json").read_text())
            self.assertEqual(manifest["id"], plugin)
            for entry_point in manifest["entryPoints"].values():
                self.assertIn(entry_point, files)

    def test_niri_display_uses_toasts_without_reserved_status_space(self) -> None:
        main = (PLUGIN_ROOT / "niri-display" / "Main.qml").read_text()
        panel = (PLUGIN_ROOT / "niri-display" / "Panel.qml").read_text()
        display_state = (PLUGIN_ROOT / "niri-display" / "DisplayState.js").read_text()

        self.assertIn("ToastService.showNotice", main)
        self.assertIn("ToastService.showError", main)
        self.assertIn("lastRefreshToastError", main)
        self.assertIn("NScrollView", panel)
        self.assertIn("geometryPlaceholder: panelContainer", panel)
        self.assertNotIn("statusSlot", panel)
        self.assertNotIn("statusState", display_state)
        self.assertNotIn("statusSlotHeight", display_state)

    def test_compact_network_status_widgets(self) -> None:
        config = (PACKAGE_ROOT / "default.nix").read_text()
        bar_widgets = (PACKAGE_ROOT / "bar-widgets.nix").read_text()
        patches = {
            path.name: path.read_text()
            for path in (PACKAGE_ROOT / "patches").glob("system-monitor-*.patch")
        }
        telemetry_patch = patches["system-monitor-gpu-telemetry.patch"]
        bar_patch = patches["system-monitor-bar-gpu-usage.patch"]
        panel_patch = patches["system-monitor-panel-gpu-card.patch"]
        widths_patch = patches["system-monitor-stable-widths.patch"]
        compact_patch = patches["system-monitor-adaptive-compact-mode.patch"]
        self.assertIn('id = "plugin:mullvad";', bar_widgets)
        self.assertIn('id = "plugin:tailscale";', bar_widgets)
        self.assertNotIn('id = "VPN";', bar_widgets)
        self.assertIn("widgets = import ./bar-widgets.nix;", config)
        self.assertIn("showNetworkStats = true;", bar_widgets)
        self.assertIn("showDiskUsage = true;", bar_widgets)
        self.assertIn("showGpuUsage = true;", bar_widgets)
        self.assertIn("useMonospaceFont = true;", bar_widgets)
        self.assertIn("usePadding = true;", bar_widgets)
        self.assertNotIn('name = "eDP-1";', config)
        self.assertNotIn('id = "plugin:gpu-usage";', bar_widgets)
        for patch_name in patches:
            self.assertIn(patch_name, config)
        self.assertIn('terminalCommand = "kitty";', config)
        self.assertNotIn("showCountryFlag", config)

        mullvad_bar = (PLUGIN_ROOT / "mullvad" / "BarWidget.qml").read_text()
        mullvad_icon = (PLUGIN_ROOT / "mullvad" / "MullvadIcon.qml").read_text()
        mullvad_logo = (PLUGIN_ROOT / "mullvad" / "mullvad.svg").read_text()
        mullvad_main = (PLUGIN_ROOT / "mullvad" / "Main.qml").read_text()
        mullvad_panel = (PLUGIN_ROOT / "mullvad" / "Panel.qml").read_text()
        tailscale_bar = (PLUGIN_ROOT / "tailscale" / "BarWidget.qml").read_text()
        tailscale_main = (PLUGIN_ROOT / "tailscale" / "Main.qml").read_text()
        tailscale_panel = (PLUGIN_ROOT / "tailscale" / "Panel.qml").read_text()
        tailscale_peer_state = (PLUGIN_ROOT / "tailscale" / "PeerState.js").read_text()
        self.assertIn("visible: installed", mullvad_bar)
        self.assertIn('source: "mullvad.svg"', mullvad_icon)
        self.assertIn("appicon_colorize.frag.qsb", mullvad_icon)
        self.assertIn('fill="#ffffff"', mullvad_logo)
        self.assertIn("property bool crossed: false", mullvad_icon)
        self.assertIn("pointSize: Style.fontSizeXL", mullvad_bar)
        self.assertIn("TailscaleIcon", tailscale_bar)
        self.assertIn("crossed: !root.tailscaleConnected && !root.tailscaleConnecting", tailscale_bar)
        self.assertIn("litColor: mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface", tailscale_bar)
        self.assertIn("allowMultiSelection: true", tailscale_panel)
        self.assertIn('icon: "refresh"', tailscale_panel)
        self.assertIn('icon: "user-share"', tailscale_panel)
        self.assertIn('icon: peerDelegate.primaryRoutes.length > 0 ? "route" : "globe"', tailscale_panel)
        self.assertIn("Layout.preferredWidth: Style.fontSizeM * 2 + Style.marginXS", tailscale_panel)
        self.assertIn("id: peerListView", tailscale_panel)
        self.assertIn("verticalPolicy: ScrollBar.AsNeeded", tailscale_panel)
        self.assertIn("wheelScrollMultiplier: 2.0", tailscale_panel)
        self.assertIn("wheelScrollMultiplier: 2.0", mullvad_panel)
        self.assertNotIn("NBox {", tailscale_panel)
        self.assertIn("? ((mainInstance?.tailscaleRunning ?? false) ? 700 : 160)", tailscale_panel)
        self.assertIn("Layout.minimumWidth: peerIpWidthProbe.implicitWidth", tailscale_panel)
        self.assertIn('"PrimaryRoutes": peer.PrimaryRoutes || []', tailscale_main)
        self.assertIn("PeerState.peerListSnapshot(nextPeers)", tailscale_main)
        self.assertIn("function peerListSnapshot(peers)", tailscale_peer_state)
        self.assertIn("ExternalTailnet", tailscale_main)
        self.assertNotIn("startTaildropReceive", tailscale_main)
        self.assertNotIn('["tailscale", "up"]', tailscale_main)
        self.assertNotIn('["tailscale", "down"]', tailscale_main)
        self.assertNotIn("toggleTailscale", tailscale_main)
        self.assertNotIn("use-exit-node", tailscale_panel)
        self.assertNotIn("Receive via Taildrop", tailscale_panel)
        self.assertNotIn("setMockPeers", tailscale_main)
        self.assertIn("setLockdownProc.requestedState = on", mullvad_main)
        self.assertIn("rowMouse.containsMouse ? Color.mOnHover", mullvad_panel)
        self.assertIn("contentPreferredHeight: 700 * Style.uiScaleRatio", mullvad_panel)
        self.assertNotIn("NCollapsible", mullvad_panel)
        self.assertIn("id: advancedContent", mullvad_panel)
        self.assertIn("onClicked: root.advancedExpanded = !root.advancedExpanded", mullvad_panel)
        self.assertIn("Layout.rightMargin: -Style.marginL", mullvad_panel)
        self.assertIn("showGradientMasks: false", mullvad_panel)
        self.assertIn("id: headerDetailsHeightProbe", mullvad_panel)
        self.assertIn("width: relayListView.availableWidth", mullvad_panel)
        self.assertIn("anchors.rightMargin: Style.marginXL", mullvad_panel)
        self.assertNotIn("confirmDisconnectInLockdown", mullvad_main)
        self.assertIn("id: gpuUsageProcess", telemetry_patch)
        self.assertIn("@intelNvtop@/bin/nvtop", telemetry_patch)
        self.assertIn('enableDgpuMonitoring', telemetry_patch)
        self.assertIn("runtime_status", telemetry_patch)
        self.assertNotIn("intel_gpu_top", telemetry_patch)
        self.assertIn("property var gpuUsageHistory", telemetry_patch)

        self.assertIn('"showGpuUsage": true', bar_patch)
        self.assertIn("id: gpuUsageContainer", bar_patch)
        self.assertIn("text: SystemStatService.gpuUsageAvailable", bar_patch)
        self.assertLess(
            bar_patch.index("id: gpuUsageContainer"),
            bar_patch.index("// CPU Frequency Component"),
        )
        self.assertIn("values: SystemStatService.gpuUsageHistory", panel_patch)

        self.assertIn("id: percentWidthReference", widths_patch)
        self.assertGreaterEqual(
            widths_patch.count(
                "Layout.preferredWidth: usePadding ? Math.ceil(percentWidthReference.implicitWidth) : -1"
            ),
            2,
        )
        for width_reference in (
            "temperatureWidthReference",
            "cpuFreqWidthReference",
            "loadWidthReference",
            "speedWidthReference",
            "memoryWidthReference",
            "swapWidthReference",
            "diskWidthReference",
        ):
            self.assertIn(f"id: {width_reference}", widths_patch)
            self.assertIn(
                f"Layout.preferredWidth: usePadding ? Math.ceil({width_reference}.implicitWidth) : -1",
                widths_patch,
            )

        self.assertIn('compactModeSetting === "auto"', compact_patch)
        self.assertIn('key: "auto"', compact_patch)
        self.assertIn('compactMode = "auto";', bar_widgets)


if __name__ == "__main__":
    unittest.main()
