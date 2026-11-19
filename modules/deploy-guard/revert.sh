# shellcheck shell=bash
# No confirmation within the window: back to the system from before the switch, now and at the next boot.
state=/run/deploy-guard
previous=$(readlink "$state/previous")
echo "Not confirmed in time; going back to $previous"
# A switch still running holds the lock and makes this one exit 11; go back once it has finished.
until
  status=0
  "$previous/bin/switch-to-configuration" switch || status=$?
  ((status != 11))
do
  sleep 5
done
# 4: units of the previous system failed, but it runs again; they show as failed units of their own.
if ((status != 0 && status != 4)); then
  echo "Going back failed: switch-to-configuration exited $status."
  exit "$status"
fi
# Only now, so a revert that fails leaves the profile on the system the machine runs and boots.
nix-env --profile /nix/var/nix/profiles/system --set "$previous"

mkdir -p "$(dirname "$METRICS_FILE")"
temporary_file=$(mktemp "$METRICS_FILE.XXXXXX")
{
  echo '# HELP deploy_guard_revert_timestamp_seconds When the machine last went back to its previous system because a switch was not confirmed.'
  echo '# TYPE deploy_guard_revert_timestamp_seconds gauge'
  echo "deploy_guard_revert_timestamp_seconds $(date +%s)"
} >"$temporary_file"
chmod 0644 "$temporary_file"
mv "$temporary_file" "$METRICS_FILE"
rm -rf "$state"
