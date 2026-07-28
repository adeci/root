{
  fetchurl,
  stdenvNoCC,
  ...
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "handy";
  version = "0.9.4";

  src = fetchurl {
    url = "https://github.com/cjpais/Handy/releases/download/v${finalAttrs.version}/Handy_aarch64.app.tar.gz";
    hash = "sha256-u/jsTP3kTcOstiVesVMsgOQOYXdC26bYZdqs+3XnJHY=";
  };

  sourceRoot = ".";
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/Applications"
    cp -R Handy.app "$out/Applications/"
    runHook postInstall
  '';

  meta = {
    description = "Free, local, open-source speech-to-text application";
    homepage = "https://handy.computer/";
    platforms = [ "aarch64-darwin" ];
    mainProgram = "handy";
  };
})
