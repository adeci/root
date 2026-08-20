{
  fetchurl,
  google-chrome,
  lib,
  makeWrapper,
  patchelf,
  stdenv,
  chromium,
  ...
}:
let
  version = "0.33.0";

  binaries = {
    x86_64-linux = "agent-browser-linux-x64";
    aarch64-linux = "agent-browser-linux-arm64";
    x86_64-darwin = "agent-browser-darwin-x64";
    aarch64-darwin = "agent-browser-darwin-arm64";
  };

  binary =
    binaries.${stdenv.hostPlatform.system}
      or (throw "agent-browser does not support ${stdenv.hostPlatform.system}");

  browser = if stdenv.hostPlatform.isDarwin then google-chrome else chromium;
in
stdenv.mkDerivation {
  pname = "agent-browser";
  inherit version;

  src = fetchurl {
    url = "https://registry.npmjs.org/agent-browser/-/agent-browser-${version}.tgz";
    hash = "sha256-Zdcyp6DFLuT1kCXvBX7ztk2GqqdiYrpk9IrBF4iJz4M=";
  };

  sourceRoot = "package";

  nativeBuildInputs = [ makeWrapper ] ++ lib.optionals stdenv.hostPlatform.isLinux [ patchelf ];

  dontBuild = true;
  dontPatchELF = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 bin/${binary} $out/libexec/agent-browser
    mkdir -p $out/share/agent-browser $out/share/skills
    cp -R skill-data $out/share/agent-browser/
    cp -R skills/agent-browser $out/share/skills/

    ${lib.optionalString stdenv.hostPlatform.isLinux ''
      patchelf \
        --set-interpreter ${stdenv.cc.bintools.dynamicLinker} \
        $out/libexec/agent-browser
    ''}

    makeWrapper $out/libexec/agent-browser $out/bin/agent-browser \
      --set-default AGENT_BROWSER_EXECUTABLE_PATH ${lib.getExe browser} \
      --set AGENT_BROWSER_SKILLS_DIR $out/share/agent-browser/skill-data

    runHook postInstall
  '';

  meta = {
    description = "Browser automation CLI for AI agents";
    homepage = "https://agent-browser.dev";
    downloadPage = "https://www.npmjs.com/package/agent-browser";
    license = lib.licenses.asl20;
    mainProgram = "agent-browser";
    platforms = builtins.attrNames binaries;
  };
}
