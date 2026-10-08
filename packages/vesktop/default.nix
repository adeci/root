{ pkgs, self, ... }:
(pkgs.vesktop.override {
  vencord = self.packages.${pkgs.stdenv.hostPlatform.system}.vencord;
  withSystemVencord = true;
}).overrideAttrs
  (oldAttrs: {
    nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ pkgs.imagemagick ];
    postPatch = (oldAttrs.postPatch or "") + ''
      # Always use the root-composed Vencord, not a stale profile override.
      substituteInPlace src/main/vencordFilesDir.ts \
        --replace-fail 'State.store.vencordDir || ' ""

      convert -coalesce ${
        pkgs.fetchurl {
          url = "https://raw.githubusercontent.com/adeci/wallpapers/refs/heads/main/nixos.gif";
          hash = "sha256-XGpc+QhVqBUvNxIarc50y8qvPAHwziR8pLI2TyBWXsQ=";
        }
      } static/splash.webp
    '';
  })
