# shellcheck shell=bash
if [[ $# -eq 0 ]]; then
  echo "Usage: net-state-rm-device <device-name> [device-name ...]"
  exit 1
fi
all_state="$(tofu state list 2>/dev/null)"
resources=()
for device in "$@"; do
  mapfile -t matched < <(echo "$all_state" | grep "$device")
  resources+=("${matched[@]}")
done
if [[ ${#resources[@]} -eq 0 ]]; then
  echo "No resources found matching: $*"
  exit 0
fi
echo "Removing ${#resources[@]} resources matching: $*"
for resource in "${resources[@]}"; do
  echo "  $resource"
done
echo ""
read -rp "Continue? [y/N] " confirm
if [[ "$confirm" != "y" ]]; then
  echo "Aborted."
  exit 0
fi
tofu state rm "${resources[@]}"
echo "Done."
