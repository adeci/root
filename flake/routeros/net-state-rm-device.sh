# shellcheck shell=bash
# net-rebuild passes --yes, as its netinstall has just wiped the device.
ask=true
if [[ ${1-} == --yes ]]; then
  ask=false
  shift
fi
if [[ $# -eq 0 ]]; then
  echo "Usage: net-state-rm-device [--yes] <device-name> [device-name ...]"
  exit 1
fi
all_state="$(tofu state pull)"
resources=()
for device in "$@"; do
  # What the state records under the device's provider configuration, so also what the config has dropped since, or a device gone from the inventory.
  mapfile -t matched < <(echo "$all_state" | jq -r --arg device "$device" '.resources[] | select(.provider | endswith("].\($device)")) | (if .mode == "data" then "data." else "" end) + .type + "." + .name')
  resources+=("${matched[@]}")
done
if [[ ${#resources[@]} -eq 0 ]]; then
  echo "No resources of $* in the state."
  exit 0
fi
if $ask; then
  echo "Removing ${#resources[@]} resources of: $*"
  for resource in "${resources[@]}"; do
    echo "  $resource"
  done
  echo ""
  read -rp "Continue? [y/N] " confirm
  if [[ "$confirm" != "y" ]]; then
    echo "Aborted."
    exit 0
  fi
fi
tofu state rm "${resources[@]}" >/dev/null
echo "Removed ${#resources[@]} resources of $* from the state."
