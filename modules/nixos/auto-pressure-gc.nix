{
  config,
  lib,
  pkgs,
  ...
}:
let
  highWaterPercent = 85;
  lowWaterPercent = 75;
  minimumProgressBytes = 1024 * 1024 * 1024;
  maximumPasses = 3;

  pressureGc = pkgs.writeShellApplication {
    name = "auto-pressure-gc";
    runtimeInputs = [
      config.nix.package
      pkgs.coreutils
    ];
    text = ''
      state_file="''${STATE_DIRECTORY:?}/filesystem-state"

      read_filesystem_usage() {
        local size used available percent

        read -r size used available percent < <(
          df --block-size=1 --output=size,used,avail,pcent /nix/store | tail -n 1
        )
        percent="''${percent%%%}"

        if [[ ! "$size" =~ ^[0-9]+$ ]] ||
           [[ ! "$used" =~ ^[0-9]+$ ]] ||
           [[ ! "$available" =~ ^[0-9]+$ ]] ||
           [[ ! "$percent" =~ ^[0-9]+$ ]]; then
          echo "Could not determine /nix/store filesystem utilization" >&2
          return 1
        fi

        printf '%s %s %s %s\n' "$size" "$used" "$available" "$percent"
      }

      above_water_mark() {
        local used=$1 available=$2 water_percent=$3
        (( 100 * used >= water_percent * (used + available) ))
      }

      bytes_to_low_water() {
        local used=$1 available=$2
        local numerator

        # GNU df calculates capacity from used + available space, excluding
        # filesystem-reserved blocks. Solve for the bytes to remove from used
        # space so that:
        #   100 * (used - freed) <= low_water * (used + available)
        numerator=$((
          (100 - ${toString lowWaterPercent}) * used -
          ${toString lowWaterPercent} * available
        ))
        printf '%s\n' "$(( (numerator + 99) / 100 ))"
      }

      read -r size used available percent < <(read_filesystem_usage)

      if ! above_water_mark "$used" "$available" ${toString highWaterPercent}; then
        echo "Disk utilization is $percent% (high water: ${toString highWaterPercent}%); no garbage collection needed"
        exit 0
      fi

      # Avoid repeatedly scanning the same set of GC roots when a collection
      # cannot reach the low-water mark. This follows Nix's own auto-GC
      # heuristic: retry after available space falls by at least 3%.
      previous_size=0
      available_after_gc=0
      if [[ -r "$state_file" ]] && read -r previous_size available_after_gc < "$state_file" &&
         [[ "$previous_size" =~ ^[0-9]+$ ]] &&
         [[ "$available_after_gc" =~ ^[0-9]+$ ]] &&
         (( size == previous_size )) &&
         (( available * 100 > available_after_gc * 97 )); then
        echo "Disk utilization is $percent%, but available space has not fallen by 3% since the previous garbage collection; skipping"
        exit 0
      fi

      pass=1
      while (( pass <= ${toString maximumPasses} )); do
        requested_bytes="$(bytes_to_low_water "$used" "$available")"
        if (( requested_bytes <= 0 )); then
          break
        fi

        echo "Disk utilization is $percent% (high water: ${toString highWaterPercent}%); pass $pass is requesting at least $requested_bytes bytes to target ${toString lowWaterPercent}%"
        nix-collect-garbage --max-freed "$requested_bytes"

        read -r final_size final_used final_available final_percent < <(read_filesystem_usage)
        progress=$(( final_available - available ))

        size=$final_size
        used=$final_used
        available=$final_available
        percent=$final_percent

        if ! above_water_mark "$used" "$available" ${toString lowWaterPercent}; then
          break
        fi

        if (( progress < ${toString minimumProgressBytes} )); then
          echo "Garbage collection made less than ${toString minimumProgressBytes} bytes of filesystem progress; suppressing another scan until available space falls by 3%" >&2
          break
        fi

        pass=$((pass + 1))
      done

      printf '%s %s\n' "$size" "$available" > "$state_file.tmp"
      mv "$state_file.tmp" "$state_file"

      if above_water_mark "$used" "$available" ${toString highWaterPercent}; then
        echo "Garbage collection completed with $used of $size bytes used ($percent%), but utilization remains above the high-water mark; it will retry after available space falls by 3%" >&2
      else
        echo "Garbage collection completed with $used of $size bytes used ($percent%)"
      fi
    '';
  };
in
{
  systemd.services.auto-pressure-gc = {
    description = "Collect unreferenced Nix store paths under disk pressure";
    after = [ "nix-daemon.service" ];
    requires = [ "nix-daemon.service" ];
    environment.NIX_REMOTE = "daemon";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe pressureGc;
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
}
