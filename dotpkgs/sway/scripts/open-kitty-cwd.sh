#!/usr/bin/env bash
# Open a new terminal in the same directory as the focused terminal

# Use swaycwd to get the current working directory of the focused window
cwd=$(swaycwd 2>/dev/null)

# If we got a valid directory, open terminal there
if [ -n "$cwd" ] && [ -d "$cwd" ]; then
    kitty --directory "$cwd" &
else
    # Fallback: open terminal in home directory
    kitty &
fi
