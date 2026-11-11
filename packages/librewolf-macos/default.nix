# LibreWolf's own macOS build. Tiling window managers can't subscribe to nixpkgs' wrapped build's accessibility notifications, so its windows go unmanaged.
{
  lib,
  stdenvNoCC,
  fetchurl,
  undmg,
  ...
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

  # The bundle must stay as shipped: fixup would strip and patch files its code signature covers.
  dontFixup = true;

  meta = {
    description = "Privacy-focused fork of Firefox (upstream macOS build)";
    homepage = "https://librewolf.net/";
    license = lib.licenses.mpl20;
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
