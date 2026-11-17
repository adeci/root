# shellcheck shell=bash
directory=$1
shift

field() {
  jq --raw-output "$1" <<< "$snapshot"
}

seconds() {
  date --date "$(field "$1")" +%s
}

for backup in "$@"; do
  output_file=$directory/restic-snapshot-$backup.prom
  temporary_file=$(mktemp "$output_file.XXXXXX")
  trap 'rm -f "$temporary_file"' EXIT

  # The restic module puts each backup's command, set up for its repository, into the system's path only.
  # --latest gives the newest snapshot of every set of paths the backup has had; the newest of those is the last run's.
  snapshot=$("/run/current-system/sw/bin/restic-$backup" snapshots --no-lock --latest 1 --json | jq 'max_by(.time)')
  taken=$(seconds .time)
  size=$(field .summary.total_bytes_processed)
  added=$(field .summary.data_added_packed)
  started=$(seconds .summary.backup_start)
  ended=$(seconds .summary.backup_end)

  {
    echo '# HELP restic_snapshot_timestamp_seconds When the newest snapshot was taken.'
    echo '# TYPE restic_snapshot_timestamp_seconds gauge'
    echo "restic_snapshot_timestamp_seconds{backup=\"$backup\"} $taken"
    echo '# HELP restic_snapshot_size_bytes The size of the files in the newest snapshot.'
    echo '# TYPE restic_snapshot_size_bytes gauge'
    echo "restic_snapshot_size_bytes{backup=\"$backup\"} $size"
    echo '# HELP restic_snapshot_added_bytes What the newest snapshot added to the repository.'
    echo '# TYPE restic_snapshot_added_bytes gauge'
    echo "restic_snapshot_added_bytes{backup=\"$backup\"} $added"
    echo '# HELP restic_snapshot_duration_seconds How long taking the newest snapshot took.'
    echo '# TYPE restic_snapshot_duration_seconds gauge'
    echo "restic_snapshot_duration_seconds{backup=\"$backup\"} $((ended - started))"
  } > "$temporary_file"

  chmod 0644 "$temporary_file"
  mv "$temporary_file" "$output_file"
done
