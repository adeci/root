# shellcheck shell=bash
# clan backups restore sets NAME and FOLDERS.
if [[ "${NAME:-}" == "" ]]; then
  echo "No backup name given via NAME environment variable" >&2
  exit 1
fi

snapshot="${NAME##*::}"
if [[ "$snapshot" == "$NAME" ]]; then
  echo "Backup name must look like '$JOB_NAME::<snapshot-id>'" >&2
  exit 1
fi

restore_folders=()
if [[ "${FOLDERS:-}" != "" ]]; then
  IFS=':' read -ra restore_folders <<<"$FOLDERS"
fi

# A state is selected when FOLDERS is empty or names one of its folders or a path inside one.
state_selected() {
  local state="$1"
  local folder_state folder requested

  if [[ "${#restore_folders[@]}" -eq 0 ]]; then
    return 0
  fi

  while IFS=$'\t' read -r folder_state folder; do
    [[ "$folder_state" == "$state" ]] || continue
    for requested in "${restore_folders[@]}"; do
      case "$requested" in
        "$folder" | "$folder"/*) return 0 ;;
      esac
    done
  done <"$STATE_FOLDERS"

  return 1
}

run_hook() {
  local hook="$1"
  local state command_hook command

  # The table is read on fd 3 so the commands keep this script's stdin.
  while IFS=$'\t' read -r -u 3 state command_hook command; do
    [[ "$command_hook" == "$hook" ]] || continue
    if state_selected "$state"; then
      echo "Running $hook command for $state"
      "/run/current-system/sw/bin/$command"
    fi
  done 3<"$STATE_COMMANDS"
}

include_args=()
while IFS=$'\t' read -r state folder; do
  state_selected "$state" || continue
  include_args+=(--include "$folder" --include "$folder/**")
done <"$STATE_FOLDERS"

if [[ "${#include_args[@]}" -eq 0 ]]; then
  echo "No clan.core.state folders matched FOLDERS" >&2
  exit 1
fi

run_hook pre-restore

"/run/current-system/sw/bin/restic-$JOB_NAME" restore "$snapshot" --target / "${include_args[@]}"

run_hook post-restore
