{
  inputs,
  lib,
  self,
  ...
}:
let
  # Builds machines for `system`; eval warnings fail, as a build only prints them.
  mkMachineChecks =
    flake: system:
    let
      onSystem = lib.filterAttrs (_: machine: machine.pkgs.stdenv.hostPlatform.system == system);
      withoutWarnings =
        name: machine: build:
        if machine.config.warnings == [ ] then
          build
        else
          throw "${name} has evaluation warnings:\n${
            lib.concatMapStrings (warning: "  - ${warning}\n") machine.config.warnings
          }";
    in
    lib.mapAttrs' (
      name: machine:
      lib.nameValuePair "nixos-${name}" (
        withoutWarnings name machine machine.config.system.build.toplevel
      )
    ) (onSystem flake.nixosConfigurations)
    // lib.mapAttrs' (
      name: machine: lib.nameValuePair "darwin-${name}" (withoutWarnings name machine machine.system)
    ) (onSystem flake.darwinConfigurations);
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

          # The home.links command through a series of switches, in a scratch home.
          home-links = callPackage ../modules/home-links/tests { };
        }
        // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
          # Alert rules, routing and the ntfy bridge; the monitoring server is Linux.
          monitoring = callPackage ../clan-services/monitoring/tests { };

          # janus's and leviathan's own alert rules, grouped as the server loads them.
          machine-rules =
            let
              ruleTests = {
                janus = import ../machines/janus/monitoring/rule-tests.nix;
                leviathan = import ../machines/leviathan/rule-tests.nix;
              };
              rules = import ../clan-services/monitoring/rules.nix {
                inherit lib;
                alwaysOn = [ ];
                machineRules = lib.mapAttrs (_: machine: machine.rules) ruleTests;
              };
              yaml = pkgs.formats.yaml { };
              rulesFile = yaml.generate "machine-rules.yml" rules.machines;
              testFile = yaml.generate "machine-rules-test.yml" {
                rule_files = [ "${rulesFile}" ];
                evaluation_interval = "1m";
                tests = lib.concatMap (machine: machine.tests) (lib.attrValues ruleTests);
              };
            in
            pkgs.runCommand "machine-rules" { nativeBuildInputs = [ pkgs.prometheus.cli ]; } ''
              promtool check rules ${rulesFile}
              promtool test rules ${testFile}
              touch $out
            '';
        };
    };
}
