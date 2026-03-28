{ self, ... }:
{
  perSystem =
    {
      self',
      pkgs,
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

      packages = lib.mapAttrs' (n: lib.nameValuePair "package-${n}") (
        lib.filterAttrs (
          _: pkg:
          let
            eval = builtins.tryEval (lib.meta.availableOn pkgs.stdenv.hostPlatform pkg);
          in
          eval.success && eval.value
        ) self'.packages
      );

      devShells = lib.mapAttrs' (n: lib.nameValuePair "devShell-${n}") self'.devShells;
    in
    {
      checks =
        lib.mapAttrs (_: machine: machine.config.system.build.toplevel) nixosMachines
        // lib.mapAttrs (_: machine: machine.system) darwinMachines
        // packages
        // devShells;
    };
}
