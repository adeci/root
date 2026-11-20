# shellcheck shell=bash
output_file=$1

# Journal MESSAGE_IDs: logind's shutdown, PID 1's unit stopping and stopped.
shutdown_announced=98268866d1d54a499c4e98921d93bc40
stopping=de5b426a63be47a7b6ac3eaac82e2f6f
stopped=9d1aaa27d60140bd96365438aad20286

seconds() { jq --null-input "($1) / 1000000"; }
manager_timestamp() { systemctl show --property "$1" --value; }

# Waits for every boot job, catch-up ones like a missed backup included.
systemctl is-system-running --wait > /dev/null || true

# µs. Firmware and loader count back from the kernel's start, the rest forward.
firmware=$(manager_timestamp FirmwareTimestampMonotonic)
loader=$(manager_timestamp LoaderTimestampMonotonic)
initrd=$(manager_timestamp InitRDTimestampMonotonic)
userspace=$(manager_timestamp UserspaceTimestampMonotonic)
finished=$(manager_timestamp FinishTimestampMonotonic)
ready=$(systemctl show multi-user.target --property ActiveEnterTimestampMonotonic --value)

# Last shutdown, logind's announcement to the last journal entry; none after a crash or first boot.
shutdown_start=$(
  journalctl --boot=-1 --output=json "MESSAGE_ID=$shutdown_announced" 2> /dev/null \
    | jq --slurp 'map(.__REALTIME_TIMESTAMP | tonumber) | max // empty'
) || true

temporary_file=$(mktemp "$output_file.XXXXXX")
trap 'rm -f "$temporary_file"' EXIT

{
  echo '# HELP boot_phase_seconds How long each phase of this boot took, as systemd-analyze counts them.'
  echo '# TYPE boot_phase_seconds gauge'
  if (( firmware > 0 )); then
    echo "boot_phase_seconds{phase=\"firmware\"} $(seconds "$firmware - $loader")"
  fi
  if (( loader > 0 )); then
    echo "boot_phase_seconds{phase=\"loader\"} $(seconds "$loader")"
  fi
  if (( initrd > 0 )); then
    echo "boot_phase_seconds{phase=\"kernel\"} $(seconds "$initrd")"
    echo "boot_phase_seconds{phase=\"initrd\"} $(seconds "$userspace - $initrd")"
  else
    echo "boot_phase_seconds{phase=\"kernel\"} $(seconds "$userspace")"
  fi
  echo "boot_phase_seconds{phase=\"userspace\"} $(seconds "$finished - $userspace")"

  echo '# HELP boot_ready_seconds From the start of the kernel until multi-user.target was reached.'
  echo '# TYPE boot_ready_seconds gauge'
  echo "boot_ready_seconds $(seconds "$ready")"
  echo '# HELP boot_finished_seconds From the start of the kernel until every job queued at boot was done.'
  echo '# TYPE boot_finished_seconds gauge'
  echo "boot_finished_seconds $(seconds "$finished")"

  echo '# HELP boot_unit_start_seconds The units slowest to start in this boot, devices aside.'
  echo '# TYPE boot_unit_start_seconds gauge'
  systemd-analyze blame --json=short | jq --raw-output '
    map(select(.unit | endswith(".device") | not))
    | .[:5][]
    | "boot_unit_start_seconds{unit=\(.unit | @json)} \(.time / 1000000)"
  '

  if [ -n "$shutdown_start" ]; then
    shutdown_end=$(journalctl --boot=-1 --output=json --lines=1 | jq '.__REALTIME_TIMESTAMP | tonumber')
    echo '# HELP shutdown_seconds How long the shutdown before this boot took.'
    echo '# TYPE shutdown_seconds gauge'
    echo "shutdown_seconds $(seconds "$shutdown_end - $shutdown_start")"

    echo '# HELP shutdown_unit_stop_seconds The units slowest to stop in that shutdown.'
    echo '# TYPE shutdown_unit_stop_seconds gauge'
    journalctl --boot=-1 --output=json _PID=1 "MESSAGE_ID=$stopping" "MESSAGE_ID=$stopped" \
      | jq --slurp --raw-output --argjson start "$shutdown_start" --arg stopping "$stopping" --arg stopped "$stopped" '
        def time: .__REALTIME_TIMESTAMP | tonumber;
        map(select(time >= $start))
        | group_by(.UNIT)
        | map({
            unit: .[0].UNIT,
            began: (map(select(.MESSAGE_ID == $stopping) | time) | min),
            ended: (map(select(.MESSAGE_ID == $stopped) | time) | max)
          })
        | map(select(.began != null and .ended != null) | {unit, seconds: ((.ended - .began) / 1000000)})
        | sort_by(.seconds) | reverse
        | .[:5][]
        | "shutdown_unit_stop_seconds{unit=\(.unit | @json)} \(.seconds)"
      '
  fi
} > "$temporary_file"

chmod 0644 "$temporary_file"
mv "$temporary_file" "$output_file"
