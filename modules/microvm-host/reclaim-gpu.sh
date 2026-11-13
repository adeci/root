# shellcheck shell=bash
gpu=$1
device=/sys/bus/pci/devices/$gpu

bound_driver() { basename "$(readlink "$device/driver" || true)"; }

echo > "$device/driver_override"
if [[ $(bound_driver) != "$GPU_HOST_DRIVER" ]]; then
  if [[ -e $device/driver ]]; then
    echo "$gpu" > "$device/driver/unbind"
  fi
  echo "$gpu" > /sys/bus/pci/drivers_probe
  if [[ $(bound_driver) != "$GPU_HOST_DRIVER" ]]; then
    echo "$gpu did not return to $GPU_HOST_DRIVER" >&2
    exit 1
  fi
fi

if ((${#GPU_HOLDERS[@]} > 0)); then
  systemctl restart "${GPU_HOLDERS[@]}"
fi
