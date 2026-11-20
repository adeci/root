# shellcheck shell=bash
workspace=$(aerospace list-workspaces --focused)
aerospace close --quit-if-last-window
# macOS may jump to the app's next window on another workspace.
sleep 0.1
aerospace workspace "$workspace"
