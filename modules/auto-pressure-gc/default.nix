let
  autoPressureGc =
    { config, pkgs }:
    pkgs.writeShellApplication {
      name = "auto-pressure-gc";
      runtimeInputs = [
        config.nix.package
        pkgs.coreutils
      ];
      runtimeEnv = {
        HIGH_WATER_PERCENT = 85;
        LOW_WATER_PERCENT = 75;
        MINIMUM_PROGRESS_BYTES = 1024 * 1024 * 1024;
        MAXIMUM_PASSES = 3;
      };
      text = builtins.readFile ./auto-pressure-gc.sh;
    };
in
{
  nixos =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      systemd.services.auto-pressure-gc = {
        description = "Collect unreferenced Nix store paths under disk pressure";
        after = [ "nix-daemon.service" ];
        requires = [ "nix-daemon.service" ];
        environment.NIX_REMOTE = "daemon";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = lib.getExe (autoPressureGc {
            inherit config pkgs;
          });
          StateDirectory = "auto-pressure-gc";

          Nice = 19;
          CPUSchedulingPolicy = "batch";
          IOSchedulingClass = "best-effort";
          IOSchedulingPriority = 7;
          IOWeight = 10;

          CapabilityBoundingSet = "";
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectHome = true;
          ProtectSystem = "strict";
        };
      };

      systemd.timers.auto-pressure-gc = {
        description = "Check Nix store disk pressure";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "5m";
          OnUnitActiveSec = "5m";
          RandomizedDelaySec = "1m";
          Unit = "auto-pressure-gc.service";
        };
      };
    };

  darwin =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      launchd.daemons.auto-pressure-gc = {
        script = ''
          mkdir -p "$STATE_DIRECTORY"
          exec ${
            lib.getExe (autoPressureGc {
              inherit config pkgs;
            })
          }
        '';
        environment = {
          NIX_REMOTE = "daemon";
          STATE_DIRECTORY = "/var/lib/auto-pressure-gc";
        };
        serviceConfig = {
          StartInterval = 300;
          Nice = 19;
          LowPriorityIO = true;
          ProcessType = "Background";
          StandardOutPath = "/var/log/auto-pressure-gc.log";
          StandardErrorPath = "/var/log/auto-pressure-gc.log";
        };
      };
    };
}
