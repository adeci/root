{
  fetchurl,
  imagemagick,
  self,
  stdenv,
  vesktop,
}:
let
  splash = fetchurl {
    url = "https://raw.githubusercontent.com/adeci/wallpapers/refs/heads/main/nixos.gif";
    hash = "sha256-XGpc+QhVqBUvNxIarc50y8qvPAHwziR8pLI2TyBWXsQ=";
  };
in
(vesktop.override {
  inherit (self.packages.${stdenv.hostPlatform.system}) vencord;
  withSystemVencord = true;
}).overrideAttrs
  (old: {
    nativeBuildInputs = old.nativeBuildInputs ++ [ imagemagick ];
    # Otherwise a vencordDir in Vesktop's state.json beats withSystemVencord.
    postPatch = (old.postPatch or "") + ''
      substituteInPlace src/main/vencordFilesDir.ts \
        --replace-fail 'State.store.vencordDir || ' ""

      convert -coalesce ${splash} static/splash.webp
    '';
    meta = old.meta // {
      platforms = [ "x86_64-linux" ];
    };
  })
