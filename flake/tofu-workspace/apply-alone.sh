# shellcheck shell=bash
# A leading non-flag argument names the device to apply alone; tofu gets the rest.
is_device() {
  jq -e --arg device "$1" 'has($device)' "$TARGETS" >/dev/null
}

device=""
if [[ $# -gt 0 && $1 != -* ]]; then
  if ! is_device "$1"; then
    echo "$1 is not a device. The devices: $(jq -r 'keys | join(", ")' "$TARGETS")"
    exit 1
  fi
  device=$1
  shift
fi
# tofu would reject a device name elsewhere only after the tunnel, secrets and device survey.
for argument in "$@"; do
  if ! is_device "$argument"; then
    continue
  fi
  if [[ -n $device ]]; then
    echo "One device at a time: net-apply $device, then net-apply $argument."
  else
    others=()
    for other in "$@"; do
      [[ $other == "$argument" ]] || others+=("$other")
    done
    echo "The device comes first: net-apply $argument ${others[*]}"
  fi
  exit 1
done

if [[ -z $device ]]; then
  exec "$APPLY" "$@"
fi
exec "$APPLY" "-target-file=$(jq -r --arg device "$device" '.[$device]' "$TARGETS")" "$@"
