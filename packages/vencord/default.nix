{
  pkgs,
  lib,
  inputs,
  plugins ? import ./plugins.nix { inherit inputs; },
  ...
}:
pkgs.vencord.overrideAttrs (
  oldAttrs:
  {
    # Vencord compiles desktop userplugins and their native helpers together.
    preBuild =
      (oldAttrs.preBuild or "")
      + "\n"
      + lib.concatStringsSep "\n" (
        lib.mapAttrsToList (name: source: ''
          mkdir -p ${lib.escapeShellArg "src/userplugins/${name}"}
          cp -R ${lib.escapeShellArg "${source}/."} ${lib.escapeShellArg "src/userplugins/${name}/"}
        '') plugins
      );
  }
  // lib.optionalAttrs (oldAttrs.version == "1.15.1") {
    # Discord removed the named modal exports used by Vencord 1.15.1.
    # Backport upstream's shared fix rather than replacing plugin settings UI.
    src =
      (pkgs.applyPatches {
        name = "vencord-modal-compatible-source";
        inherit (oldAttrs) src;
        patches = [
          (pkgs.fetchurl {
            url = "https://github.com/Vendicated/Vencord/commit/90aea0ddbbfbee16ce052b2c7ab610ffe957b4ca.patch";
            hash = "sha256-fldDGIClghkJdOD1FbiKvxTCK1qqKMq5zDNcVvC1Ilk=";
          })
        ];
      })
      // {
        # nixpkgs derives VENCORD_REMOTE from the source's GitHub metadata.
        inherit (oldAttrs.src) owner repo;
      };
  }
)
