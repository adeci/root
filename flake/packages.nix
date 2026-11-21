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

      # availablePackages hides a package that fails to evaluate; one available on no system is broken.
      unavailableEverywhere = lib.filter (
        name: !lib.any (systemPackages: systemPackages ? ${name}) (lib.attrValues self.packages)
      ) (lib.attrNames (nixEntries ../packages // nixEntries ../wrappers));
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
        // lib.genAttrs unavailableEverywhere (
          name:
          throw "${name} is available on no system: it fails to evaluate, or its platforms exclude them all"
        )
      );
    };
}
