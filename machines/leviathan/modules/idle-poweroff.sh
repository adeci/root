# shellcheck shell=bash
stream=$1
idle_seconds=$2

mkdir -p /run/idle-poweroff
cd /run/idle-poweroff || exit
rx=$(cat /sys/class/net/lan/statistics/rx_bytes)
downloaded=$((rx - $(cat rx 2>/dev/null || echo "$rx")))
echo "$rx" > rx
if [ ! -e busy ] || [ -e "$stream" ] || [ "$downloaded" -ge $((60 << 20)) ] ||
  loginctl list-sessions --json=short | jq -e 'any(.[]; .class == "user")' > /dev/null; then
  date +%s > busy
elif [ $(($(date +%s) - $(cat busy))) -ge "$idle_seconds" ]; then
  systemctl poweroff
fi
