{
  inputs,
  lib,
  self,
  ...
}:
let
  # Builds each of a flake's NixOS and darwin machines whose platform is `system`.
  mkMachineChecks =
    flake: system:
    let
      onSystem = lib.filterAttrs (_: machine: machine.pkgs.stdenv.hostPlatform.system == system);
    in
    lib.mapAttrs' (
      name: machine: lib.nameValuePair "nixos-${name}" machine.config.system.build.toplevel
    ) (onSystem flake.nixosConfigurations)
    // lib.mapAttrs' (name: machine: lib.nameValuePair "darwin-${name}" machine.system) (
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
    let
      callPackage = pkgs.newScope { inherit self inputs; };
    in
    {
      checks =
        mkMachineChecks self system
        // lib.mapAttrs' (name: lib.nameValuePair "devShell-${name}") config.devShells
        // {
          # Reading the inventory runs its checks.
          inventory = pkgs.writeText "inventory" (lib.concatLines (lib.attrNames self.inventory));
        }
        // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
          # Alert rules, routing and the ntfy bridge, all of which run on the Linux monitoring server.
          monitoring = callPackage ../clan-services/monitoring/tests { };
        };
    };
}
