{
  pkgs,
  lib,
  ...
}:
let
  inherit (pkgs)
    stdenv
    fetchurl
    undmg
    ;
  srcs = lib.importJSON ./srcs.json;
in
stdenv.mkDerivation {
  pname = "librewolf";
  inherit (srcs) version;

  src = fetchurl {
    inherit (srcs) url hash;
  };

  nativeBuildInputs = [ undmg ];

  sourceRoot = ".";

  # Override with policies attrset to inject policies.json into the app bundle
  passthru.withPolicies =
    policies:
    stdenv.mkDerivation {
      pname = "librewolf-with-policies";
      inherit (srcs) version;

      src = fetchurl {
        inherit (srcs) url hash;
      };

      nativeBuildInputs = [ undmg ];

      sourceRoot = ".";

      installPhase = ''
        runHook preInstall
        mkdir -p "$out/Applications"
        cp -r LibreWolf.app "$out/Applications/"
        mkdir -p "$out/Applications/LibreWolf.app/Contents/Resources/distribution"
        echo '${builtins.toJSON { inherit policies; }}' \
          > "$out/Applications/LibreWolf.app/Contents/Resources/distribution/policies.json"
        runHook postInstall
      '';

      meta = {
        description = "A privacy-focused fork of Firefox (with policies)";
        homepage = "https://librewolf.net/";
        license = lib.licenses.mpl20;
        platforms = [ "aarch64-darwin" ];
      };
    };

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/Applications"
    cp -r LibreWolf.app "$out/Applications/"
    runHook postInstall
  '';

  meta = {
    description = "A privacy-focused fork of Firefox";
    homepage = "https://librewolf.net/";
    license = lib.licenses.mpl20;
    platforms = [ "aarch64-darwin" ];
  };
}
