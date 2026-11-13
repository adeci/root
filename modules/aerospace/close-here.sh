# shellcheck shell=bash
workspace=$(aerospace list-workspaces --focused)
aerospace close --quit-if-last-window
# macOS may now focus the app's next window on another workspace; come back to where the close started.
sleep 0.1
aerospace workspace "$workspace"
