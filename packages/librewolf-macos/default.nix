# Upstream's build: tiling WMs can't track nixpkgs' wrapped app.
{
  lib,
  stdenvNoCC,
  fetchurl,
  undmg,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "librewolf";
  version = "159.0.1-1";

  src = fetchurl {
    url = "https://dl.librewolf.net/librewolf/${finalAttrs.version}/librewolf-${finalAttrs.version}-macos-arm64-package.dmg";
    hash = "sha256-7ZKxOgFQWf2i4n6LLF3n2AGEPl+g1+6SsRvUh/XGi/Q=";
  };

  nativeBuildInputs = [ undmg ];
  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/Applications"
    cp -R LibreWolf.app "$out/Applications/"
    runHook postInstall
  '';

  # fixup would break the code signature.
  dontFixup = true;

  meta = {
    description = "Privacy-focused fork of Firefox (upstream macOS build)";
    homepage = "https://librewolf.net/";
    license = lib.licenses.mpl20;
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
