{
  lib,
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
    python3
    qt6.qtdeclarative
  ];
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    ${lib.getExe python3} -m unittest -v test_plugin_assets.py

    mkdir -p test-root/plugins/niri-display test-root/tests
    for asset in BarWidget.qml DisplayState.js Main.qml Panel.qml manifest.json; do
      cp "plugins/niri-display/$asset" "test-root/plugins/niri-display/$asset"
      cmp "plugins/niri-display/$asset" "test-root/plugins/niri-display/$asset"
    done
    cp tests/tst_DisplayState.qml test-root/tests/
    cmp tests/tst_DisplayState.qml test-root/tests/tst_DisplayState.qml
    XDG_CACHE_HOME="$TMPDIR/cache" QT_QPA_PLATFORM=offscreen \
      QML2_IMPORT_PATH="${qt6.qtdeclarative}/lib/qt-6/qml:${qt6.qtbase}/lib/qt-6/qml" \
      ${lib.getExe' qt6.qtdeclarative "qmltestrunner"} -input test-root/tests -platform offscreen
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/plugins/niri-display"
    for asset in BarWidget.qml DisplayState.js Main.qml Panel.qml manifest.json; do
      cp "plugins/niri-display/$asset" "$out/plugins/niri-display/$asset"
      cmp "plugins/niri-display/$asset" "$out/plugins/niri-display/$asset"
    done
    runHook postInstall
  '';
}
