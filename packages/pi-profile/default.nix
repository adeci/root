{
  stdenvNoCC,
  bash,
  coreutils,
  diffutils,
  makeWrapper,
  python3,
  ...
}:
stdenvNoCC.mkDerivation {
  name = "pi-profile";
  dontUnpack = true;
  nativeBuildInputs = [ makeWrapper ];
  nativeCheckInputs = [ python3 ];
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    ${python3.interpreter} ${./test_install.py} "$out"
    runHook postInstallCheck
  '';

  installPhase = # bash
    ''
      runHook preInstall
      mkdir -p $out/share/pi-profile/themes $out/bin
      install -m444 ${./AGENTS.md} $out/share/pi-profile/AGENTS.md
      install -m444 ${./APPEND_SYSTEM.md} $out/share/pi-profile/APPEND_SYSTEM.md
      install -m444 ${./themes/tokyo-night.json} $out/share/pi-profile/themes/tokyo-night.json
      install -m755 ${./install.sh} $out/bin/pi-profile-install
      substituteInPlace $out/bin/pi-profile-install \
        --replace-fail '#!/usr/bin/env bash' '#!${bash}/bin/bash' \
        --replace-fail '@profile@' "$out/share/pi-profile"
      wrapProgram $out/bin/pi-profile-install --prefix PATH : ${coreutils}/bin:${diffutils}/bin
      runHook postInstall
    '';
}
