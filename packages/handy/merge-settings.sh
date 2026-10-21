# shellcheck shell=bash
# Deep-merge the declared settings ($1) into Handy's settings store: declared
# keys win, the GUI keeps every other key, an unparseable store is left alone.

declared=$1
[ -n "${HOME:-}" ] || exit 0
case "$(uname -s)" in
  Darwin) store_dir="$HOME/Library/Application Support/com.pais.handy" ;;
  *) store_dir="${XDG_DATA_HOME:-$HOME/.local/share}/com.pais.handy" ;;
esac
store="$store_dir/settings_store.json"

if [ ! -e "$store" ]; then
  # First start: Handy fills every undeclared key from its defaults. The
  # store can hold API keys, so keep it private.
  mkdir -p "$store_dir"
  cp "$declared" "$store"
  chmod 600 "$store"
  exit 0
fi

merged=$(jq -c -s '.[0] * .[1]' "$store" "$declared" 2>/dev/null) || exit 0
# Skip the write when nothing changed, so CLI calls never race GUI edits.
if [ -z "$merged" ] || [ "$merged" = "$(jq -c . "$store")" ]; then
  exit 0
fi

tmp=$(mktemp "$store_dir/.settings_store.json.XXXXXX")
trap 'rm -f "$tmp"' EXIT
printf '%s\n' "$merged" >"$tmp"
chmod --reference="$store" "$tmp"
mv -f "$tmp" "$store"
