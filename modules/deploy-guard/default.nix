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
          description = "Seconds to confirm a switch (`clan machines update` or `deploy-guard-confirm`) before the machine reverts.";
        };

        checks = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          description = "Health checks by name, run with coreutils and systemd on PATH. A switch is confirmed only if every check that passed before it still passes.";
        };
      };

      config = {
        # Name order puts this after home-links and switchInhibitors: refused switches don't arm.
        system.preSwitchChecks.wait-for-confirmation = ''${lib.getExe arm} "$1" "$2"'';

        environment.systemPackages = [ confirm ];
      };
    };
}
