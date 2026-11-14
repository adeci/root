# shellcheck shell=bash
applied=$1
declaration=$2
workflows=$3

if [[ "$(cat "$applied" 2>/dev/null)" != "$declaration" ]]; then
  paperless-manage shell --no-imports --command "$(cat "$workflows")"
  echo "$declaration" > "$applied"
fi
