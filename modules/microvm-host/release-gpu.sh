# shellcheck shell=bash
gpu=$1

if ((${#GPU_HOLDERS[@]} > 0)); then
  systemctl stop "${GPU_HOLDERS[@]}"
fi

# The NVIDIA driver blocks unbinding a GPU anything still has open, so refuse while any process, CUDA or graphics, holds its /dev/nvidia<minor>.
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
