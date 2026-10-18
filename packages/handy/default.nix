{
  lib,
  pkgs,
  stdenvNoCC,
  fetchurl,
  undmg,
  wtype,
  symlinkJoin,
  makeWrapper,
  ...
}:
let
  # Linux: the nixpkgs source build links nixpkgs GTK and GSettings, so it
  # follows the desktop cursor and theme settings. Handy types transcripts with
  # an external tool from PATH; without wtype it falls back to X11 XTest, which
  # reaches only XWayland windows. Wrap the cached build instead of overriding
  # it, so the Rust/Tauri build still comes from the binary cache.
  handy-linux = symlinkJoin {
    name = "handy-${pkgs.handy.version}";
    paths = [ pkgs.handy ];
    nativeBuildInputs = [ makeWrapper ];
    postBuild = ''
      wrapProgram "$out/bin/handy" --prefix PATH : ${lib.makeBinPath [ wtype ]}
    '';
    inherit (pkgs.handy) meta;
  };

  # Darwin: keep the upstream signed app. macOS ties microphone and
  # accessibility permissions to the code signature.
  handy-darwin = stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "handy";
    version = "0.9.6";

    src = fetchurl {
      url = "https://github.com/cjpais/Handy/releases/download/v${finalAttrs.version}/Handy_${finalAttrs.version}_aarch64.dmg";
      hash = "sha256-qWGzVyT2yGC83Ozh8dd8ITQ60hVlJfiADKlooarU2FQ=";
    };

    nativeBuildInputs = [ undmg ];

    sourceRoot = ".";

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/Applications" "$out/bin"
      cp -R Handy.app "$out/Applications/"
      ln -s "$out/Applications/Handy.app/Contents/MacOS/handy" "$out/bin/handy"

      runHook postInstall
    '';

    meta = {
      description = "Free, local, open-source speech-to-text application";
      homepage = "https://handy.computer/";
      platforms = [ "aarch64-darwin" ];
      mainProgram = "handy";
    };
  });
in
if stdenvNoCC.hostPlatform.isDarwin then handy-darwin else handy-linux
