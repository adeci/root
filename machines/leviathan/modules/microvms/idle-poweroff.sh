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
packets=$(iptables -t mangle -vnxL PREROUTING | awk '/moonlight-client/ { n += $1; found = 1 } END { if (found) print n }')
client=$(grown client "${packets:?no rule counts the client}")

if [ ! -e busy ] || [ "$client" -gt 0 ] || [ "$downloaded" -ge $((60 << 20)) ] ||
  loginctl list-sessions --json=short | jq -e 'any(.[]; .class == "user")' > /dev/null; then
  date +%s > busy
else
  # A game left running waits longer than an empty seat.
  [ ! -e "$stream" ] || idle_seconds=$resume_seconds
  if [ $(($(date +%s) - $(cat busy))) -ge "$idle_seconds" ]; then
    systemctl poweroff
  fi
fi
