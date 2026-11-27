# shellcheck shell=bash
stream=$1
idle_seconds=$2
resume_seconds=$3

mkdir -p /run/idle-poweroff
cd /run/idle-poweroff || exit

# How much a counter grew since the last run.
grown() {
  echo $(($2 - $(cat "$1" 2> /dev/null || echo "$2")))
  echo "$2" > "$1"
}

downloaded=$(grown rx "$(cat /sys/class/net/lan/statistics/rx_bytes)")
# Moonshine keeps a session, and keeps sending, long after its client has gone. What the client sends is the
# only sign that one is there. Without the counting rule this fails, and the seat stays on.
count_packets() {
  "$1" -t mangle -vnxL PREROUTING 2> /dev/null |
    awk '/moonlight-client/ { n += $1; found = 1 } END { if (found) print n }'
}
v4=$(count_packets iptables)
v6=$(count_packets ip6tables || true)
packets=$((${v4:?no rule counts the client} + ${v6:-0}))
client=$(grown client "$packets")

now=$(cut -d. -f1 /proc/uptime)
if [ ! -e busy ] || [ "$client" -gt 0 ] || [ "$downloaded" -ge $((60 << 20)) ] ||
  loginctl list-sessions --json=short | jq -e 'any(.[]; .class == "user")' > /dev/null; then
  echo "$now" > busy
else
  # A game left running waits longer than an empty seat.
  [ ! -e "$stream" ] || idle_seconds=$resume_seconds
  if [ $((now - $(cat busy))) -ge "$idle_seconds" ]; then
    systemctl poweroff
  fi
fi
