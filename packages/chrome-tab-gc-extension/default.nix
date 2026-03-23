{
  pkgs,
  lib,
  ...
}:
let
  inherit (pkgs)
    stdenv
    fetchurl
    unzip
    zip
    jq
    ;
in
stdenv.mkDerivation {
  pname = "chrome-tab-gc-extension";
  version = "1.2";

  src = fetchurl {
    url = "https://github.com/Mic92/chrome-tab-gc/releases/download/1.2/tab_garbage_collector-1.2.xpi";
    hash = "sha256-vXGjpHHT95g3Am5b3YGCZv4GKK6MV0uV5aPsAo4QT7g=";
  };

  nativeBuildInputs = [
    unzip
    zip
    jq
  ];

  unpackPhase = ''
    mkdir -p source
    unzip "$src" -d source
  '';

  buildPhase = ''
    cd source
    if ! jq -e '.browser_specific_settings.gecko.id' manifest.json >/dev/null 2>&1; then
      jq '. + {"browser_specific_settings": {"gecko": {"id": "tab-garbage-collector@thalheim.io"}}}' \
        manifest.json > manifest.json.tmp
      mv manifest.json.tmp manifest.json
    fi
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    zip -r "$out/chrome-tab-gc-extension.xpi" .
    runHook postInstall
  '';

  meta = {
    description = "Tab Garbage Collector - closes tabs not viewed for a long time";
    homepage = "https://github.com/Mic92/chrome-tab-gc";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
