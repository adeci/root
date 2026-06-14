{
  curl,
  lib,
  python3,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation {
  pname = "llm-weights-prepare";
  version = "0.1.0";

  src = ./.;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -D -m 0755 prepare.py $out/bin/llm-weights-prepare
    substituteInPlace $out/bin/llm-weights-prepare \
      --replace-fail '#!/usr/bin/env python3' '#!${python3}/bin/python' \
      --replace-fail '@curl@' '${curl}/bin/curl'

    runHook postInstall
  '';

  meta = {
    description = "Prepare Leviathan's local GGUF model weight store";
    mainProgram = "llm-weights-prepare";
    platforms = lib.platforms.linux;
  };
}
