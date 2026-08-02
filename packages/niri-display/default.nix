{
  lib,
  niri,
  python3,
  stdenvNoCC,
  systemd,
  wl-mirror,
  ...
}:
stdenvNoCC.mkDerivation {
  pname = "niri-display";
  version = "1.0.0";

  src = ./.;
  dontConfigure = true;
  dontBuild = true;

  nativeCheckInputs = [ python3 ];
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    ${lib.getExe python3} -m unittest -v test_niri_display.py
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin"
    substituteAll niri_display.py "$out/bin/niri-display"
    chmod +x "$out/bin/niri-display"
    runHook postInstall
  '';

  python = lib.getExe python3;
  niri = lib.getExe niri;
  wl_mirror = lib.getExe wl-mirror;
  systemctl = "${systemd}/bin/systemctl";
  systemd_run = "${systemd}/bin/systemd-run";

  meta = {
    description = "Runtime-only niri display and wl-mirror control";
    license = lib.licenses.mit;
    mainProgram = "niri-display";
    platforms = lib.platforms.linux;
  };
}
