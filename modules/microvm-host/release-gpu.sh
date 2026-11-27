# shellcheck shell=bash
gpu=$1
pci_setup=$2
device=/sys/bus/pci/devices/$gpu

bound_driver() { basename "$(readlink "$device/driver" || true)"; }

# One hand-over at a time. Two that overlap issue opposite jobs for the holders, systemd cancels one side's,
# and that VM fails to start.
exec 9> /run/microvm-gpu.lock
flock 9

if ((${#GPU_HOLDERS[@]} > 0)); then
  systemctl stop "${GPU_HOLDERS[@]}"
fi

# nvidia blocks unbinding a GPU that's still open; refuse while /dev/nvidia<minor> is held.
# On failure here or in pci_setup, ExecStopPost runs reclaim-gpu.sh to restore the holders once.
if [[ $GPU_HOST_DRIVER == nvidia && $(bound_driver) == nvidia ]]; then
  info="/proc/driver/nvidia/gpus/$gpu/information"
  if [[ ! -r $info ]]; then
    echo "$gpu is bound to nvidia, but $info is missing" >&2
    exit 1
  fi
  minor=$(sed -n 's/^Device Minor:[[:space:]]*//p' "$info")
  minor=${minor:?could not determine nvidia minor for $gpu}
  # find fails on processes that exit while it walks /proc.
  pids=$({ find /proc/[0-9]*/fd -lname "/dev/nvidia$minor" 2> /dev/null || true; } | cut -d/ -f3 | sort -u)
  if [[ -n $pids ]]; then
    echo "$gpu is in use by:" >&2
    ps -o pid=,user=,args= -p "${pids//$'\n'/,}" >&2 || true
    exit 1
  fi
fi

# Bind to vfio-pci under the lock before the holders come back, so they never see an unbound device.
"$pci_setup" 9>&-

# When this was the host's last GPU, some of them have nothing to hold and fail to start.
if ((${#GPU_HOLDERS[@]} > 0)); then
  systemctl start "${GPU_HOLDERS[@]}" || true
fi
