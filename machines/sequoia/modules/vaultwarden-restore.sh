# shellcheck shell=bash
backup_dir=$1
data_dir=$2

install -d -m 0700 -o vaultwarden -g vaultwarden "$data_dir"
rsync -a --delete "$backup_dir/" "$data_dir/"
chown -R vaultwarden:vaultwarden "$data_dir"
