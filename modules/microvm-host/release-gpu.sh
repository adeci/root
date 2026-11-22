# shellcheck shell=bash
gpu=$1
device=/sys/bus/pci/devices/$gpu

# One hand-over at a time. Two that overlap issue opposite jobs for the holders, systemd cancels one side's,
# and that VM fails to start.
exec 9> /run/microvm-gpu.lock
flock 9

if ((${#GPU_HOLDERS[@]} > 0)); then
  systemctl stop "${GPU_HOLDERS[@]}"
fi

# nvidia blocks unbinding a GPU that's still open; refuse while /dev/nvidia<minor> is held.
if [[ $GPU_HOST_DRIVER == nvidia ]]; then
  minor=$(sed -n 's/^Device Minor:[[:space:]]*//p' "/proc/driver/nvidia/gpus/$gpu/information")
  # find fails on processes that exit while it walks /proc.
  pids=$({ find /proc/[0-9]*/fd -lname "/dev/nvidia$minor" 2>/dev/null || true; } | cut -d/ -f3 | sort -u)
  if [[ -n $pids ]]; then
    echo "$gpu is in use by:" >&2
    ps -o pid=,user=,args= -p "${pids//$'\n'/,}" >&2 || true
    if ((${#GPU_HOLDERS[@]} > 0)); then
      systemctl start "${GPU_HOLDERS[@]}"
    fi
    exit 1
  fi
fi

# Off the host's driver, and kept off it, before the holders come back. The VM's own setup binds it next.
echo vfio-pci > "$device/driver_override"
if [[ -e $device/driver ]]; then
  echo "$gpu" > "$device/driver/unbind"
fi
# When this was the host's last GPU, some of them have nothing to hold and fail to start.
if ((${#GPU_HOLDERS[@]} > 0)); then
  systemctl start "${GPU_HOLDERS[@]}" || true
fi
