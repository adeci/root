{
  nixos =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      metricsFile = "${config.monitoring.textfileDirectory}/deploy-guard.prom";

      # One executable per check, named after it.
      checks = pkgs.linkFarm "deploy-guard-checks" (
        lib.mapAttrs (
          name: command: pkgs.writeShellScript "deploy-guard-check-${name}" command
        ) config.deployGuard.checks
      );

      revert = pkgs.writeShellApplication {
        name = "deploy-guard-revert";
        runtimeInputs = [
          config.nix.package
          pkgs.coreutils
        ];
        runtimeEnv.METRICS_FILE = metricsFile;
        text = builtins.readFile ./revert.sh;
      };

      arm = pkgs.writeShellApplication {
        name = "deploy-guard-arm";
        runtimeInputs = [
          config.nix.package
          config.systemd.package
          pkgs.coreutils
        ];
        runtimeEnv = {
          WINDOW_SECONDS = config.deployGuard.window;
          CHECKS = checks;
          REVERT = lib.getExe revert;
        };
        text = builtins.readFile ./arm.sh;
      };

      confirm = pkgs.writeShellApplication {
        name = "deploy-guard-confirm";
        runtimeInputs = [
          config.systemd.package
          pkgs.coreutils
        ];
        runtimeEnv = {
          CHECKS = checks;
          METRICS_FILE = metricsFile;
        };
        text = builtins.readFile ./confirm.sh;
      };
    in
    {
      options.deployGuard = {
        window = lib.mkOption {
          type = lib.types.ints.positive;
          description = "Seconds a switch waits to be confirmed, by `clan machines update` or by hand with `deploy-guard-confirm`, before the machine goes back to the system it ran before.";
        };

        checks = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          description = "Shell commands, by name, that succeed while the machine does its job; they run with coreutils and systemd on the PATH. A switch is confirmed only if each one that passed just before it passes after it.";
        };
      };

      config = {
        # Pre-switch checks run in name order, so this one follows home-links and nixpkgs' switchInhibitors: a switch they refuse arms nothing.
        system.preSwitchChecks.wait-for-confirmation = ''${lib.getExe arm} "$1" "$2"'';

        environment.systemPackages = [ confirm ];
      };
    };
}
