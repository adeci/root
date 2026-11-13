# shellcheck shell=bash
user=$1 target=$2 link=$3

if [[ -e $link && ! -L $link ]]; then
  echo "home.links: $link is not a symlink; left alone" >&2
else
  /usr/bin/sudo -u "$user" -- /bin/mkdir -p "$(/usr/bin/dirname "$link")"
  /usr/bin/sudo -u "$user" -- /bin/ln -sfn "$target" "$link"
fi
