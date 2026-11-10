{ self, ... }:
{
  perSystem =
    {
      config,
      lib,
      system,
      ...
    }:
    let
      nixosMachines = lib.mapAttrs' (n: lib.nameValuePair "nixos-${n}") (
        lib.filterAttrs (
          _name: machine: machine.pkgs.stdenv.hostPlatform.system == system
        ) self.nixosConfigurations
      );

      darwinMachines = lib.mapAttrs' (n: lib.nameValuePair "darwin-${n}") (
        lib.filterAttrs (_name: machine: machine.pkgs.stdenv.hostPlatform.system == system) (
          self.darwinConfigurations or { }
        )
      );

      devShells = lib.mapAttrs' (n: lib.nameValuePair "devShell-${n}") config.devShells;
    in
    {
      # Packages add their own checks where they're defined.
      checks =
        lib.mapAttrs (_: machine: machine.config.system.build.toplevel) nixosMachines
        // lib.mapAttrs (_: machine: machine.system) darwinMachines
        // devShells;
    };
}
