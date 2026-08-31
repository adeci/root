{
  bash,
  coreutils,
  gawk,
  gnupatch,
  jq,
  lib,
  noctalia-qs,
  noctalia-shell,
  nvtopPackages,
  pkgs,
  python3,
  qt6,
  stdenvNoCC,
  ...
}:
stdenvNoCC.mkDerivation {
  pname = "noctalia-shell-plugin-tests";
  version = "1.0.0";
  src = ./.;

  dontConfigure = true;
  dontBuild = true;
  dontWrapQtApps = true;

  nativeCheckInputs = [
    bash
    coreutils
    gawk
    gnupatch
    jq
    noctalia-qs
    python3
    qt6.qtdeclarative
  ];
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    ${lib.getExe python3} -m unittest -v test_plugin_assets.py
    for qml in plugins/mullvad/*.qml plugins/niri-display/*.qml plugins/tailscale/*.qml; do
      ${lib.getExe' qt6.qtdeclarative "qmlformat"} "$qml" >/dev/null
    done

    mkdir -p \
      patched-noctalia/Assets \
      patched-noctalia/Modules/Bar/Widgets \
      patched-noctalia/Modules/Panels/Settings/Bar/WidgetSettings \
      patched-noctalia/Modules/Panels/SystemStats \
      patched-noctalia/Services/System \
      patched-noctalia/Services/UI
    cp ${noctalia-shell.src}/Assets/settings-widgets-default.json \
      patched-noctalia/Assets/settings-widgets-default.json
    cp ${noctalia-shell.src}/Modules/Bar/Widgets/SystemMonitor.qml \
      patched-noctalia/Modules/Bar/Widgets/SystemMonitor.qml
    cp ${noctalia-shell.src}/Modules/Panels/Settings/Bar/WidgetSettings/SystemMonitorSettings.qml \
      patched-noctalia/Modules/Panels/Settings/Bar/WidgetSettings/SystemMonitorSettings.qml
    cp ${noctalia-shell.src}/Modules/Panels/SystemStats/SystemStatsPanel.qml \
      patched-noctalia/Modules/Panels/SystemStats/SystemStatsPanel.qml
    cp ${noctalia-shell.src}/Services/System/SystemStatService.qml \
      patched-noctalia/Services/System/SystemStatService.qml
    cp ${noctalia-shell.src}/Services/UI/BarWidgetRegistry.qml \
      patched-noctalia/Services/UI/BarWidgetRegistry.qml
    chmod -R u+w patched-noctalia
    for patchFile in \
      patches/system-monitor-gpu-telemetry.patch \
      patches/system-monitor-bar-gpu-usage.patch \
      patches/system-monitor-panel-gpu-card.patch \
      patches/system-monitor-stable-widths.patch \
      patches/system-monitor-adaptive-compact-mode.patch; do
      patch -d patched-noctalia -p1 < "$patchFile"
    done
    substituteInPlace patched-noctalia/Services/System/SystemStatService.qml \
      --replace-fail @intelNvtop@ ${nvtopPackages.intel} \
      --replace-fail @jq@ ${lib.getExe' jq "jq"} \
      --replace-fail @gawk@ ${gawk} \
      --replace-fail @nvidiaSmi@ ${lib.getBin pkgs.linuxPackages.nvidia_x11} \
      --replace-fail @coreutils@ ${coreutils} \
      --replace-fail @bash@ ${bash}
    test -x '${lib.getExe' pkgs.linuxPackages.nvidia_x11 "nvidia-smi"}'
    grep -F '${lib.getExe' pkgs.linuxPackages.nvidia_x11 "nvidia-smi"}' \
      patched-noctalia/Services/System/SystemStatService.qml
    for qml in \
      patched-noctalia/Modules/Bar/Widgets/SystemMonitor.qml \
      patched-noctalia/Modules/Panels/Settings/Bar/WidgetSettings/SystemMonitorSettings.qml \
      patched-noctalia/Modules/Panels/SystemStats/SystemStatsPanel.qml \
      patched-noctalia/Services/System/SystemStatService.qml; do
      ${lib.getExe' qt6.qtdeclarative "qmlformat"} "$qml" >/dev/null
    done
    ${lib.getExe python3} test_gpu_telemetry.py \
      patched-noctalia/Services/System/SystemStatService.qml

    # Load the patched service, rather than merely formatting it. Lightweight
    # singletons isolate SystemStatService from the rest of the shell while
    # retaining the actual Quickshell Process/FileView types.
    mkdir -p qml-load/Services/System qml-load/Test/Stubs
    cp patched-noctalia/Services/System/SystemStatService.qml qml-load/Services/System/
    substituteInPlace qml-load/Services/System/SystemStatService.qml \
      --replace-fail 'import qs.Commons' 'import Test.Stubs' \
      --replace-fail 'import qs.Services.UI' ""
    cat > qml-load/Test/Stubs/qmldir <<EOF
    module Test.Stubs
    singleton Logger 1.0 Logger.qml
    singleton Settings 1.0 Settings.qml
    singleton Color 1.0 Color.qml
    singleton PanelService 1.0 PanelService.qml
    singleton Time 1.0 Time.qml
    EOF
    cat > qml-load/Test/Stubs/Logger.qml <<EOF
    pragma Singleton
    import QtQuick
    QtObject { function d() {} function i() {} function w() {} }
    EOF
    cat > qml-load/Test/Stubs/Settings.qml <<EOF
    pragma Singleton
    import QtQuick
    QtObject {
      property QtObject systemMonitor: QtObject {
        property bool enableDgpuMonitoring: false
        property bool useCustomColors: false
        property string warningColor: ""
        property string criticalColor: ""
        property int cpuWarningThreshold: 1
        property int cpuCriticalThreshold: 1
        property int tempWarningThreshold: 1
        property int tempCriticalThreshold: 1
        property int gpuWarningThreshold: 1
        property int gpuCriticalThreshold: 1
        property int memWarningThreshold: 1
        property int memCriticalThreshold: 1
        property int swapWarningThreshold: 1
        property int swapCriticalThreshold: 1
        property int diskWarningThreshold: 1
        property int diskCriticalThreshold: 1
        property int diskAvailWarningThreshold: 1
        property int diskAvailCriticalThreshold: 1
      }
      property var data: ({ systemMonitor: systemMonitor })
    }
    EOF
    cat > qml-load/Test/Stubs/Color.qml <<EOF
    pragma Singleton
    import QtQuick
    QtObject { property color mTertiary: "white"; property color mError: "red" }
    EOF
    cat > qml-load/Test/Stubs/PanelService.qml <<EOF
    pragma Singleton
    import QtQuick
    QtObject { property var lockScreen: null }
    EOF
    cat > qml-load/Test/Stubs/Time.qml <<EOF
    pragma Singleton
    import QtQuick
    QtObject { signal resumed() }
    EOF
    cat > qml-load/shell.qml <<EOF
    import QtQuick
    import Quickshell
    import "Services/System" as System
    ShellRoot {
      Component.onCompleted: {
        System.SystemStatService.gpuUsage
        Qt.quit()
      }
    }
    EOF
    mkdir -p "$TMPDIR/runtime"
    set +e
    XDG_CACHE_HOME="$TMPDIR/cache" XDG_RUNTIME_DIR="$TMPDIR/runtime" QT_QPA_PLATFORM=offscreen \
      QML2_IMPORT_PATH="$PWD/qml-load:${qt6.qtdeclarative}/lib/qt-6/qml:${qt6.qtbase}/lib/qt-6/qml" \
      ${coreutils}/bin/timeout 5 ${lib.getExe noctalia-qs} -p "$PWD/qml-load" --no-color \
      > qml-load.log 2>&1
    qml_load_status=$?
    set -e
    [ "$qml_load_status" -eq 124 ]
    grep -q 'Configuration Loaded' qml-load.log

    grep -q 'id: gpuUsageProcess' patched-noctalia/Services/System/SystemStatService.qml
    grep -q 'enableDgpuMonitoring' patched-noctalia/Services/System/SystemStatService.qml
    grep -q 'id: gpuUsageContainer' patched-noctalia/Modules/Bar/Widgets/SystemMonitor.qml
    grep -q 'compactModeSetting === "auto"' patched-noctalia/Modules/Bar/Widgets/SystemMonitor.qml
    grep -q 'key: "auto"' patched-noctalia/Modules/Panels/Settings/Bar/WidgetSettings/SystemMonitorSettings.qml
    grep -q 'values: SystemStatService.gpuUsageHistory' \
      patched-noctalia/Modules/Panels/SystemStats/SystemStatsPanel.qml

    mkdir -p test-root/plugins/niri-display test-root/plugins/tailscale test-root/tests
    for asset in BarWidget.qml DisplayState.js Main.qml Panel.qml manifest.json; do
      cp "plugins/niri-display/$asset" "test-root/plugins/niri-display/$asset"
      cmp "plugins/niri-display/$asset" "test-root/plugins/niri-display/$asset"
    done
    cp plugins/tailscale/PeerState.js test-root/plugins/tailscale/
    cmp plugins/tailscale/PeerState.js test-root/plugins/tailscale/PeerState.js
    for test in tst_DisplayState.qml tst_PeerState.qml; do
      cp "tests/$test" "test-root/tests/$test"
      cmp "tests/$test" "test-root/tests/$test"
    done
    XDG_CACHE_HOME="$TMPDIR/cache" QT_QPA_PLATFORM=offscreen \
      QML2_IMPORT_PATH="${qt6.qtdeclarative}/lib/qt-6/qml:${qt6.qtbase}/lib/qt-6/qml" \
      ${lib.getExe' qt6.qtdeclarative "qmltestrunner"} -input test-root/tests -platform offscreen
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/plugins"
    for plugin in mullvad niri-display tailscale voxtype; do
      cp -R "plugins/$plugin" "$out/plugins/$plugin"
      diff -qr "plugins/$plugin" "$out/plugins/$plugin"
    done
    runHook postInstall
  '';
}
