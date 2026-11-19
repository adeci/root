# shellcheck shell=bash
# Starts the backup once it is due, unless no network comes up, it is metered or the repository's server is out of reach; says why not.
restic=/run/current-system/sw/bin/restic-$JOB_NAME

# After a sleep this runs before NetworkManager has the network back.
if ! nm-online --quiet --timeout 60; then
  echo "Not backing up: no network"
  exit 0
fi

if [[ $(nmcli --terse --fields METERED general) == yes* ]]; then
  echo "Not backing up: the network is metered"
  exit 0
fi

# Any answer from an S3 server will do; one that refuses the key is then the backup's failure, not a reason to wait.
if [[ "$REPOSITORY" == s3:* ]]; then
  server=${REPOSITORY#s3:}
  server=${server#*://}
  server=${server%%/*}
  if ! curl --silent --head --max-time 10 --output /dev/null "https://$server/"; then
    echo "Not backing up: $server does not answer"
    exit 0
  fi
fi

# Without a repository (status 10) the backup makes one; any other error is the backup's to report.
status=0
snapshots=$("$restic" snapshots --no-lock --latest 1 --json) || status=$?
if [[ "$status" -eq 0 ]]; then
  newest=$(jq --raw-output 'max_by(.time) | .time // empty' <<<"$snapshots")
  if [[ -n "$newest" ]] && (($(date +%s) - $(date --date "$newest" +%s) < 20 * 3600)); then
    echo "Not backing up: the newest snapshot, of $newest, is less than 20 hours old"
    exit 0
  fi
fi

echo "Starting the backup"
systemctl start --no-block "restic-backups-$JOB_NAME.service"
