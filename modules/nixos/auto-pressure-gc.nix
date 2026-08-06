{
  config,
  lib,
  pkgs,
  ...
}:
let
  thresholdPercent = 85;
  cooldownSeconds = 6 * 60 * 60;

  pressureGc = pkgs.writeShellApplication {
    name = "auto-pressure-gc";
    runtimeInputs = [
      config.nix.package
      pkgs.coreutils
      pkgs.gawk
    ];
    text = ''
      usage="$(df --output=pcent /nix/store | awk 'NR == 2 { gsub(/%/, "", $1); print $1 }')"
      if [[ ! "$usage" =~ ^[0-9]+$ ]]; then
        echo "Could not determine disk utilization for /nix/store: $usage" >&2
        exit 1
      fi

      if (( usage < ${toString thresholdPercent} )); then
        echo "Disk utilization is $usage% (threshold: ${toString thresholdPercent}%); no garbage collection needed"
        exit 0
      fi

      state_file="''${STATE_DIRECTORY:?}/last-run"
      now="$(date +%s)"
      last_run=0
      if [[ -r "$state_file" ]] && ! read -r last_run < "$state_file"; then
        last_run=0
      fi

      if [[ "$last_run" =~ ^[0-9]+$ ]] && (( now - last_run < ${toString cooldownSeconds} )); then
        echo "Disk utilization is $usage% (threshold: ${toString thresholdPercent}%); garbage collection skipped because the six-hour cooldown is active"
        exit 0
      fi

      echo "Disk utilization is $usage% (threshold: ${toString thresholdPercent}%); running nix-collect-garbage"
      nix-collect-garbage

      final_usage="$(df --output=pcent /nix/store | awk 'NR == 2 { gsub(/%/, "", $1); print $1 }')"
      echo "Garbage collection completed; disk utilization is now $final_usage%"

      printf '%s\n' "$now" > "$state_file.tmp"
      mv "$state_file.tmp" "$state_file"
    '';
  };
in
{
  systemd.services.auto-pressure-gc = {
    description = "Collect unreferenced Nix store paths under disk pressure";
    after = [ "nix-daemon.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe pressureGc;
      StateDirectory = "auto-pressure-gc";
      Nice = 19;
      IOSchedulingClass = "idle";
      IOSchedulingPriority = 7;
      IOWeight = 1;
    };
  };

  systemd.timers.auto-pressure-gc = {
    description = "Check Nix store disk pressure";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5m";
      OnUnitActiveSec = "10m";
      RandomizedDelaySec = "1m";
      Unit = "auto-pressure-gc.service";
    };
  };
}
