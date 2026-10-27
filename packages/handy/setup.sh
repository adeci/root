# shellcheck shell=bash
# Prepare Handy's data dir: deep-merge the declared settings ($1) into its
# settings store (declared keys win, the GUI keeps every other key, an
# unparseable store is left alone) and link each declared model file ($2/*)
# into its models dir, dropping links to models no longer declared.

declared=$1
declared_models=$2
[ -n "${HOME:-}" ] || exit 0
case "$(uname -s)" in
  Darwin) store_dir="$HOME/Library/Application Support/com.pais.handy" ;;
  *) store_dir="${XDG_DATA_HOME:-$HOME/.local/share}/com.pais.handy" ;;
esac
store="$store_dir/settings_store.json"
models_dir="$store_dir/models"

mkdir -p "$models_dir"
for link in "$models_dir"/*; do
  [ -L "$link" ] || continue
  target=$(readlink "$link")
  case $target in
    /nix/store/*) [ "$target" = "$declared_models/${link##*/}" ] || rm -f "$link" ;;
  esac
done
for model in "$declared_models"/*; do
  link="$models_dir/${model##*/}"
  [ "$(readlink "$link" 2>/dev/null)" = "$model" ] || ln -sfn "$model" "$link"
done

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
