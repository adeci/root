# shellcheck shell=bash
directory=$1
# One "<backup>\t<path>" line for each folder a backup holds, and for each pattern it leaves out of them.
folders=$2
excludes=$3
shift 3

field() {
  jq --raw-output "$1" <<< "$snapshot"
}

seconds() {
  date --date "$(field "$1")" +%s
}

# A path as a label's value: node_exporter drops the whole file over a backslash or a quote left bare.
label() {
  local value=${1//\\/\\\\}
  value=${value//\"/\\\"}
  echo "$value"
}

for backup in "$@"; do
  output_file=$directory/restic-snapshot-$backup.prom
  temporary_file=$(mktemp "$output_file.XXXXXX")
  trap 'rm -f "$temporary_file"' EXIT

  # The restic module puts each backup's command, set up for its repository, into the system's path only.
  restic=/run/current-system/sw/bin/restic-$backup
  status=0
  snapshots=$("$restic" snapshots --no-lock --json) || status=$?
  # Before the first backup there is no repository (10) or no snapshot in it: the newest counts as taken at 0, so the machine alerts.
  if [[ "$status" -eq 10 ]]; then
    snapshots='[]'
  elif [[ "$status" -ne 0 ]]; then
    exit "$status"
  fi
  # restic lists the snapshots oldest first, by their times; compared as text, times with different offsets would come out of order.
  snapshot=$(jq '.[-1]' <<< "$snapshots")
  if [[ "$snapshot" == null ]]; then
    taken=0
  else
    taken=$(seconds .time)
    size=$(field .summary.total_bytes_processed)
    started=$(seconds .summary.backup_start)
    ended=$(seconds .summary.backup_end)
    count=$(jq length <<< "$snapshots")
    oldest=$(date --date "$(jq --raw-output '.[0].time' <<< "$snapshots")" +%s)

    # date reads the times, which carry their time zone's offset.
    week_ago=$(($(date +%s) - 7 * 86400))
    added_this_week=0
    while read -r time bytes; do
      if (($(date --date "$time" +%s) > week_ago)); then
        added_this_week=$((added_this_week + bytes))
      fi
    done < <(jq --raw-output '.[] | "\(.time) \(.summary.data_added_packed // 0)"' <<< "$snapshots")

    # stats reads the folder listings of every snapshot, half a minute of CPU and 450 MB on a home like praxis's, so it runs again only once the snapshots have changed; one that fails is tried again the next hour, and the rest is written meanwhile.
    listed=$(jq --raw-output '[.[].id] | sort | join(" ")' <<< "$snapshots")
    if [[ "$listed" == "$(cat "$STATE_DIRECTORY/$backup.snapshots" 2> /dev/null)" ]]; then
      stored=$(< "$STATE_DIRECTORY/$backup.stored")
    elif stored=$("$restic" stats --no-lock --mode raw-data --json | jq .total_size); then
      echo "$stored" > "$STATE_DIRECTORY/$backup.stored"
      echo "$listed" > "$STATE_DIRECTORY/$backup.snapshots"
    else
      stored=
    fi
  fi

  {
    echo '# HELP restic_snapshot_timestamp_seconds When the newest snapshot was taken, 0 while there is none.'
    echo '# TYPE restic_snapshot_timestamp_seconds gauge'
    echo "restic_snapshot_timestamp_seconds{backup=\"$backup\"} $taken"
    if [[ "$snapshot" != null ]]; then
      echo '# HELP restic_snapshot_size_bytes The size of the files in the newest snapshot.'
      echo '# TYPE restic_snapshot_size_bytes gauge'
      echo "restic_snapshot_size_bytes{backup=\"$backup\"} $size"
      echo '# HELP restic_snapshot_duration_seconds How long taking the newest snapshot took.'
      echo '# TYPE restic_snapshot_duration_seconds gauge'
      echo "restic_snapshot_duration_seconds{backup=\"$backup\"} $((ended - started))"
      echo '# HELP restic_snapshots How many snapshots the repository keeps.'
      echo '# TYPE restic_snapshots gauge'
      echo "restic_snapshots{backup=\"$backup\"} $count"
      echo '# HELP restic_oldest_snapshot_timestamp_seconds When the oldest snapshot was taken.'
      echo '# TYPE restic_oldest_snapshot_timestamp_seconds gauge'
      echo "restic_oldest_snapshot_timestamp_seconds{backup=\"$backup\"} $oldest"
      echo '# HELP restic_week_added_bytes What the snapshots of the last 7 days added to the repository.'
      echo '# TYPE restic_week_added_bytes gauge'
      echo "restic_week_added_bytes{backup=\"$backup\"} $added_this_week"
      if [[ -n "$stored" ]]; then
        echo '# HELP restic_repository_size_bytes What the snapshots take up in the repository, deduplicated and compressed.'
        echo '# TYPE restic_repository_size_bytes gauge'
        echo "restic_repository_size_bytes{backup=\"$backup\"} $stored"
      fi
    fi
    echo '# HELP restic_backup_folder_info A folder the backup holds.'
    echo '# TYPE restic_backup_folder_info gauge'
    while IFS=$'\t' read -r folder_backup folder; do
      if [[ "$folder_backup" == "$backup" ]]; then
        echo "restic_backup_folder_info{backup=\"$backup\",folder=\"$(label "$folder")\"} 1"
      fi
    done < "$folders"
    echo '# HELP restic_backup_exclude_info A pattern the backup leaves out of its folders.'
    echo '# TYPE restic_backup_exclude_info gauge'
    while IFS=$'\t' read -r pattern_backup pattern; do
      if [[ "$pattern_backup" == "$backup" ]]; then
        echo "restic_backup_exclude_info{backup=\"$backup\",pattern=\"$(label "$pattern")\"} 1"
      fi
    done < "$excludes"
  } > "$temporary_file"

  chmod 0644 "$temporary_file"
  mv "$temporary_file" "$output_file"
done
