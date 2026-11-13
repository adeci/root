# shellcheck shell=bash
data_dir=$1
backup_dir=$2

install -d -m 0700 -o vaultwarden -g vaultwarden "$backup_dir"

if [ ! -d "$data_dir" ]; then
  echo "No Vaultwarden data dir, skipping backup snapshot"
  exit 0
fi

if [ -f "$data_dir/db.sqlite3" ]; then
  sqlite3 "$data_dir/db.sqlite3" ".backup '$backup_dir/db.sqlite3'"
fi
rsync -a --delete --exclude 'db.sqlite3*' "$data_dir/" "$backup_dir/"
chown -R vaultwarden:vaultwarden "$backup_dir"
