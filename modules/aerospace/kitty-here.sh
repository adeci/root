# shellcheck shell=bash
app_pid=$(osascript -e 'tell application "System Events" to unix id of first process whose frontmost is true' 2>/dev/null) || true
if [ -n "$app_pid" ]; then
  shell_pid=$(ps -eo pid=,ppid=,comm= | awk -v ppid="$app_pid" '$2==ppid && /fish$|bash$|zsh$/ {print $1; exit}') || true
  if [ -n "$shell_pid" ]; then
    directory=$(lsof -a -p "$shell_pid" -d cwd -Fn 2>/dev/null | awk '/^n\//{ print substr($0,2)}') || true
    if [ -n "$directory" ] && [ -d "$directory" ]; then
      exec "$KITTY" -d "$directory"
    fi
  fi
fi
exec "$KITTY"
