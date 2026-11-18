# shellcheck shell=bash
hook=$1
failed=0

# restic would save a link without what it points to.
if [[ "$hook" == pre-backup ]]; then
  while IFS=$'\t' read -r state folder; do
    if [[ -L "$folder" ]]; then
      echo "$state's folder $folder is a link to $(readlink -f "$folder"): declare that folder instead" >&2
      failed=1
    fi
  done <"$STATE_FOLDERS"
  if [[ "$failed" -ne 0 ]]; then
    exit 1
  fi
fi

# The table is read on fd 3 so the commands keep this script's stdin.
while IFS=$'\t' read -r -u 3 state command_hook command; do
  [[ "$command_hook" == "$hook" ]] || continue
  echo "Running $hook command for $state"
  if ! "/run/current-system/sw/bin/$command"; then
    echo "$hook command failed for $state" >&2
    failed=1
  fi
done 3<"$STATE_COMMANDS"

if [[ "$failed" -ne 0 ]]; then
  exit 1
fi
