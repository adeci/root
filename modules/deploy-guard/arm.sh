# shellcheck shell=bash
# Pre-switch check: $1 is the new system, $2 the action.
new=$1
action=$2
state=/run/deploy-guard
shopt -s nullglob

if [[ $action != switch && $action != test ]]; then
  exit 0
fi
current=$(readlink -f /run/current-system)
if [[ $current == "$(readlink -f "$new")" ]]; then
  exit 0
fi
# Don't arm for the revert's own switch.
if systemctl --quiet is-active deploy-guard-revert.service; then
  exit 0
fi

if systemctl --quiet is-active deploy-guard-revert.timer; then
  # Stacked unconfirmed switch: new window, still back to the original system.
  systemctl restart deploy-guard-revert.timer
else
  rm -rf "$state"
  mkdir -p "$state/passed"
  # GC root, so the previous system stays in the store.
  nix-store --realise "$current" --add-root "$state/previous" >/dev/null
  for check in "$CHECKS"/*; do
    if timeout 30 "$check" >/dev/null 2>&1; then
      touch "$state/passed/${check##*/}"
    else
      echo "deploy-guard: ${check##*/} already fails, so it does not count against this switch"
    fi
  done
  # A failed revert stays failed (for the alert) until the next switch arms.
  systemctl reset-failed deploy-guard-revert.service 2>/dev/null || true
  systemd-run --quiet --unit=deploy-guard-revert --on-active="$WINDOW_SECONDS" --timer-property=AccuracySec=1s "$REVERT"
fi
date --date="$WINDOW_SECONDS seconds" +'%H:%M:%S %Z' >"$state/deadline"
echo "deploy-guard: $HOSTNAME goes back to its previous system at $(<"$state/deadline") unless this switch is confirmed or it restarts first"
