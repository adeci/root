# shellcheck shell=bash
# Not confirmed in time: switch back, now and for the next boot.
state=/run/deploy-guard
previous=$(readlink "$state/previous")
echo "Not confirmed in time; going back to $previous"
# Exit 11: a running switch holds the lock; retry until it's done.
until
  status=0
  "$previous/bin/switch-to-configuration" switch || status=$?
  ((status != 11))
do
  sleep 5
done
# 4: some units failed, but the previous system is running.
if ((status != 0 && status != 4)); then
  echo "Going back failed: switch-to-configuration exited $status."
  exit "$status"
fi
# Only after success, so a failed revert leaves the profile on what runs.
nix-env --profile /nix/var/nix/profiles/system --set "$previous"

mkdir -p "$(dirname "$METRICS_FILE")"
temporary_file=$(mktemp "$METRICS_FILE.XXXXXX")
{
  echo '# HELP deploy_guard_revert_timestamp_seconds Last revert of an unconfirmed switch.'
  echo '# TYPE deploy_guard_revert_timestamp_seconds gauge'
  echo "deploy_guard_revert_timestamp_seconds $(date +%s)"
} >"$temporary_file"
chmod 0644 "$temporary_file"
mv "$temporary_file" "$METRICS_FILE"
rm -rf "$state"
