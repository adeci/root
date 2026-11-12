{ lib, self, ... }:
let
  # Builds each of a flake's NixOS and darwin machines whose platform is `system`.
  mkMachineChecks =
    flake: system:
    let
      onSystem = lib.filterAttrs (_name: machine: machine.pkgs.stdenv.hostPlatform.system == system);
    in
    lib.mapAttrs' (n: machine: lib.nameValuePair "nixos-${n}" machine.config.system.build.toplevel) (
      onSystem flake.nixosConfigurations
    )
    // lib.mapAttrs' (n: machine: lib.nameValuePair "darwin-${n}" machine.system) (
      onSystem flake.darwinConfigurations
    );
in
{
  flake.lib.mkMachineChecks = mkMachineChecks;

  perSystem =
    {
      config,
      pkgs,
      system,
      ...
    }:
    {
      # Packages add their own checks where they're defined.
      checks =
        mkMachineChecks self system
        // lib.mapAttrs' (n: lib.nameValuePair "devShell-${n}") config.devShells
        // {
          # Reading every resource runs the inventory checks.
          inventory = pkgs.writeText "inventory" (
            lib.concatLines (lib.mapAttrsToList (name: resource: builtins.seq resource name) self.resources)
          );
        };
    };
}
