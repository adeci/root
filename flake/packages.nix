{
  inputs,
  lib,
  self,
  ...
}:
let
  inherit (import ./lib.nix { inherit lib; }) nixEntries availablePackages;

  # Heavy GUI builds, not worth routine checks.
  skipChecks = [
    "emacs"
    "karabiner-elements"
    "prusa-slicer"
    "vencord"
    "vesktop"
    "zipline"
  ];
in
{
  perSystem =
    { config, pkgs, ... }:
    let
      callPackage = pkgs.newScope { inherit self inputs; };

      packages = availablePackages pkgs.stdenv.hostPlatform (
        lib.mapAttrs (_: path: callPackage path { }) (nixEntries ../packages)
      );
    in
    {
      inherit packages;

      apps.mac-install.program = packages.mac-install;
      apps.update-locks.program = packages.update-locks;

      # Packages from packages/ and the exported wrappers build in `nix flake check`.
      checks = lib.mapAttrs' (name: lib.nameValuePair "package-${name}") (
        removeAttrs (
          packages // lib.getAttrs (lib.attrNames config.wrappers.packages) config.packages
        ) skipChecks
      );
    };
}
