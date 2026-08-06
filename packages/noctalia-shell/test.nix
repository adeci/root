{
  gnupatch,
  lib,
  noctalia-shell,
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
    gnupatch
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
      patched-noctalia/Modules/Panels/SystemStats \
      patched-noctalia/Services/System \
      patched-noctalia/Services/UI
    cp ${noctalia-shell.src}/Assets/settings-widgets-default.json \
      patched-noctalia/Assets/settings-widgets-default.json
    cp ${noctalia-shell.src}/Modules/Bar/Widgets/SystemMonitor.qml \
      patched-noctalia/Modules/Bar/Widgets/SystemMonitor.qml
    cp ${noctalia-shell.src}/Modules/Panels/SystemStats/SystemStatsPanel.qml \
      patched-noctalia/Modules/Panels/SystemStats/SystemStatsPanel.qml
    cp ${noctalia-shell.src}/Services/System/SystemStatService.qml \
      patched-noctalia/Services/System/SystemStatService.qml
    cp ${noctalia-shell.src}/Services/UI/BarWidgetRegistry.qml \
      patched-noctalia/Services/UI/BarWidgetRegistry.qml
    chmod -R u+w patched-noctalia
    patch -d patched-noctalia -p1 < patches/system-monitor-gpu-usage.patch
    for qml in \
      patched-noctalia/Modules/Bar/Widgets/SystemMonitor.qml \
      patched-noctalia/Modules/Panels/SystemStats/SystemStatsPanel.qml \
      patched-noctalia/Services/System/SystemStatService.qml; do
      ${lib.getExe' qt6.qtdeclarative "qmlformat"} "$qml" >/dev/null
    done
    grep -q 'id: gpuUsageContainer' patched-noctalia/Modules/Bar/Widgets/SystemMonitor.qml
    grep -q 'values: SystemStatService.gpuUsageHistory' \
      patched-noctalia/Modules/Panels/SystemStats/SystemStatsPanel.qml
    grep -q 'id: gpuUsageProcess' patched-noctalia/Services/System/SystemStatService.qml

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
