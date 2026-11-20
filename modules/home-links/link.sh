# shellcheck shell=bash
# home-links [--check] TABLE, where each line of TABLE is "link<TAB>target".
check_only=false
if [[ $1 == --check ]]; then
  check_only=true
  shift
fi
table=$1

clobbered=false
while IFS=$'\t' read -r link _; do
  if [[ -e $link && ! -L $link ]]; then
    echo "home.links: $link exists and is not a link; move it away and switch again." >&2
    clobbered=true
  fi
done <"$table"
if [[ $clobbered == true ]]; then
  exit 1
fi
if [[ $check_only == true ]]; then
  exit 0
fi

# Table from the last run, any generation; without one, remove nothing.
record=${STATE_DIRECTORY:?}/linked
declare -A named
while IFS=$'\t' read -r link _; do
  named[$link]=1
done <"$table"
if [[ -f $record ]]; then
  while IFS=$'\t' read -r link target; do
    # Only if it still points where the last run left it.
    if [[ -z ${named[$link]-} && -L $link && $(readlink "$link") == "$target" ]]; then
      echo "home.links: removing $link, whose entry is gone"
      rm "$link"
      # And the folders left empty, up to $HOME.
      folder=$(dirname "$link")
      while [[ $folder != "$HOME" ]] && rmdir "$folder" 2>/dev/null; do
        folder=$(dirname "$folder")
      done
    fi
  done <"$record"
fi

while IFS=$'\t' read -r link target; do
  mkdir -p "$(dirname "$link")"
  ln -sfnT "$target" "$link"
done <"$table"

cat "$table" >"$record.tmp"
mv "$record.tmp" "$record"
