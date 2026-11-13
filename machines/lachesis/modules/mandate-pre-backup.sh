# shellcheck shell=bash
umask 0077
install -d -m 0700 "$BACKUP_DIRECTORY"
rm -rf "${BACKUP_DIRECTORY:?}"/*
for database in "$STATE_DIRECTORY"/connectors/*/data.db; do
  if [ -f "$database" ]; then
    snapshot=$BACKUP_DIRECTORY/$(basename "$(dirname "$database")").db
    sqlite3 "$database" ".backup $snapshot"
    # Media refs go, as some embed CDN keys.
    if [ -n "$(sqlite3 "$snapshot" "SELECT 1 FROM sqlite_master WHERE name = 'media'")" ]; then
      sqlite3 "$snapshot" "UPDATE media SET ref = NULL; VACUUM;"
    fi
  fi
done
if [ -d "$STATE_DIRECTORY/owner" ]; then
  cp -r "$STATE_DIRECTORY/owner" "$BACKUP_DIRECTORY/owner"
fi
if [ -f "$STATE_DIRECTORY/gateway/live.json" ]; then
  cp "$STATE_DIRECTORY/gateway/live.json" "$BACKUP_DIRECTORY/gateway-live.json"
fi
