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
      # Automatically check all NixOS machines that match this system
      nixosMachines = lib.mapAttrs' (n: lib.nameValuePair "nixos-${n}") (
        lib.filterAttrs (
          _name: machine: machine.pkgs.stdenv.hostPlatform.system == system
        ) self.nixosConfigurations
      );

      # Automatically check all Darwin machines that match this system
      darwinMachines = lib.mapAttrs' (n: lib.nameValuePair "darwin-${n}") (
        lib.filterAttrs (_name: machine: machine.pkgs.stdenv.hostPlatform.system == system) (
          self.darwinConfigurations or { }
        )
      );

      devShells = lib.mapAttrs' (n: lib.nameValuePair "devShell-${n}") config.devShells;
    in
    {
      # Package checks come from flake/packages.nix.
      checks =
        lib.mapAttrs (_: machine: machine.config.system.build.toplevel) nixosMachines
        // lib.mapAttrs (_: machine: machine.system) darwinMachines
        // devShells;
    };
}
