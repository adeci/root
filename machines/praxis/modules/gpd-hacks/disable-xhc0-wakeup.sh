# shellcheck shell=bash
# Writing the name toggles, so a restart (e.g. a switch after a bash bump) would re-enable it.
if grep -q '^XHC0\s.*\*enabled' /proc/acpi/wakeup; then
  echo XHC0 > /proc/acpi/wakeup
fi
