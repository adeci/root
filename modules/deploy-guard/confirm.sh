# shellcheck shell=bash
# deploy-guard-confirm [SYSTEM], over a new connection after a switch.
# With SYSTEM, refuses once the machine runs another (e.g. after a revert).
system=${1-}
state=/run/deploy-guard
shopt -s nullglob

if systemctl --quiet is-active deploy-guard-revert.service; then
  echo "Not confirmed: the window has ended, and $HOSTNAME is going back to its previous system."
  exit 1
fi
if [[ -n $system && $(readlink -f /run/current-system) != "$(readlink -f "$system")" ]]; then
  echo "Not confirmed: $HOSTNAME no longer runs $system."
  exit 1
fi
if ! systemctl --quiet is-active deploy-guard-revert.timer; then
  echo "No switch is waiting to be confirmed."
  # Reaching the machine after a revert clears the revert metric.
  rm -f "$METRICS_FILE"
  exit 0
fi

failing=()
for check in "$CHECKS"/*; do
  name=${check##*/}
  if [[ ! -e $state/passed/$name ]]; then
    echo "$name: failed before the switch too, so it does not count"
  elif timeout 30 "$check"; then
    echo "$name: passes"
  else
    echo "$name: fails"
    failing+=("$name")
  fi
done
if ((${#failing[@]} > 0)); then
  echo "Not confirmed: ${failing[*]} passed before the switch and fails now; $HOSTNAME goes back to its previous system at $(<"$state/deadline") unless it restarts first."
  exit 1
fi

systemctl stop deploy-guard-revert.timer
# The window may have ended while the checks ran.
if systemctl --quiet is-active deploy-guard-revert.service; then
  echo "Not confirmed: the window has ended, and $HOSTNAME is going back to its previous system."
  exit 1
fi
rm -rf "$state" "$METRICS_FILE"

failed_units=$(systemctl list-units --state=failed --plain --no-legend --no-pager | cut -d ' ' -f 1 | paste -sd ' ')
if [[ -n $failed_units ]]; then
  echo "Failed units, which the switch keeps: $failed_units"
fi
echo "Confirmed: $HOSTNAME stays on this system."
