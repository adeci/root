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
    echo "home.links: $link would be clobbered: it exists and is not a link. Move it away, then switch again." >&2
    clobbered=true
  fi
done <"$table"
if [[ $clobbered == true ]]; then
  exit 1
fi
if [[ $check_only == true ]]; then
  exit 0
fi

while IFS=$'\t' read -r link target; do
  mkdir -p "$(dirname "$link")"
  ln -sfnT "$target" "$link"
done <"$table"
