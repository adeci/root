# shellcheck shell=bash
kitty_pid=$(niri msg -j focused-window 2>/dev/null | jq -r 'select(.app_id == "kitty") | .pid') || true
if [ -n "$kitty_pid" ]; then
  shell_pid=$(ps -o pid=,tty= --ppid "$kitty_pid" | awk '!/[?]/ { print $1; exit }') || true
  if [ -n "$shell_pid" ]; then
    exec "$KITTY" -d "$(readlink -f /proc/"$shell_pid"/cwd)"
  fi
fi
exec "$KITTY"
