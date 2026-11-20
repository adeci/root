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
      };
      text = builtins.readFile ./auto-pressure-gc.sh;
    };

  # Nix's own GC runs as paths are added, covering big builds between timer runs.
  nixSettings = {
    min-free = 10 * 1024 * 1024 * 1024;
    max-free = 50 * 1024 * 1024 * 1024;
  };

  # Only deletes old generations; auto-pressure-gc frees their paths.
  nixGc = {
    automatic = true;
    options = "--delete-older-than 14d --max-freed 0";
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

      nix.settings = nixSettings;
      nix.gc = nixGc // {
        dates = "weekly";
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

      nix.settings = nixSettings;
      # nix-darwin's default schedule is already weekly.
      nix.gc = nixGc;
    };
}
