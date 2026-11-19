# shellcheck shell=bash
# switch-to-configuration runs this before it changes anything, with the system it switches to and its action.
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
# The revert switches back itself, and nothing reverts that.
if systemctl --quiet is-active deploy-guard-revert.service; then
  exit 0
fi

if systemctl --quiet is-active deploy-guard-revert.timer; then
  # A switch on top of one still unconfirmed gets a fresh window, back to the system from before both.
  systemctl restart deploy-guard-revert.timer
else
  rm -rf "$state"
  mkdir -p "$state/passed"
  # Also a root for the garbage collector, so the system to go back to stays in the store.
  nix-store --realise "$current" --add-root "$state/previous" >/dev/null
  for check in "$CHECKS"/*; do
    if timeout 30 "$check" >/dev/null 2>&1; then
      touch "$state/passed/${check##*/}"
    else
      echo "deploy-guard: ${check##*/} already fails, so it does not count against this switch"
    fi
  done
  # A revert that failed stays a failed unit, for the fleet's alert, until a later switch arms anew.
  systemctl reset-failed deploy-guard-revert.service 2>/dev/null || true
  systemd-run --quiet --unit=deploy-guard-revert --on-active="$WINDOW_SECONDS" --timer-property=AccuracySec=1s "$REVERT"
fi
date --date="$WINDOW_SECONDS seconds" +'%H:%M:%S %Z' >"$state/deadline"
echo "deploy-guard: $HOSTNAME goes back to its previous system at $(<"$state/deadline") unless this switch is confirmed or it restarts first"
