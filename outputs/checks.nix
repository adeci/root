{ self, ... }:
{
  perSystem =
    {
      self',
      lib,
      system,
      ...
    }:
    let
      # Automatically check all NixOS machines that match this system
      nixosMachines = lib.mapAttrs' (n: lib.nameValuePair "nixos-${n}") (
        lib.filterAttrs (
          _name: machine: machine.pkgs.stdenv.hostPlatform.system == system
        ) self.nixosConfigurations
      );

      packages = lib.mapAttrs' (n: lib.nameValuePair "package-${n}") self'.packages;

      devShells = lib.mapAttrs' (n: lib.nameValuePair "devShell-${n}") self'.devShells;
    in
    {
      checks =
        lib.mapAttrs (_: machine: machine.config.system.build.toplevel) nixosMachines
        // packages
        // devShells;
    };
}
