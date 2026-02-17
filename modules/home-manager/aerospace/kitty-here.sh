#!/bin/bash
# Spawn kitty in the same working directory as the focused terminal window.
# Falls back to a plain kitty if detection fails.

# Get the PID of the frontmost application
APP_PID=$(osascript -e 'tell application "System Events" to unix id of first process whose frontmost is true' 2>/dev/null)

if [ -n "$APP_PID" ]; then
  # Find the child shell process (oldest child = the shell)
  SHELL_PID=$(pgrep -oP "$APP_PID" 2>/dev/null)

  if [ -n "$SHELL_PID" ]; then
    # Get the shell's current working directory
    CWD=$(lsof -p "$SHELL_PID" 2>/dev/null | awk '/cwd/{print $NF}')

    if [ -n "$CWD" ] && [ -d "$CWD" ]; then
      exec kitty -d "$CWD"
    fi
  fi
fi

exec kitty
