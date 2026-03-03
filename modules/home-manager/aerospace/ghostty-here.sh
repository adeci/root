#!/bin/bash
# Spawn ghostty in the same working directory as the focused terminal window.
# Falls back to a plain ghostty if detection fails.

# Get the PID of the frontmost application
APP_PID=$(osascript -e 'tell application "System Events" to unix id of first process whose frontmost is true' 2>/dev/null)

if [ -n "$APP_PID" ]; then
  # Find the child shell process (fish/bash/zsh), skipping intermediates
  SHELL_PID=$(ps -eo pid=,ppid=,comm= | awk -v ppid="$APP_PID" '$2==ppid && /fish$|bash$|zsh$/ {print $1; exit}')

  if [ -n "$SHELL_PID" ]; then
    # Get the shell's current working directory
    CWD=$(lsof -a -p "$SHELL_PID" -d cwd -Fn 2>/dev/null | awk '/^n\//{print substr($0,2)}')

    if [ -n "$CWD" ] && [ -d "$CWD" ]; then
      exec ghostty --working-directory="$CWD"
    fi
  fi
fi

exec ghostty
