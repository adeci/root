# shellcheck shell=bash
jq -n --arg secret "$(clan secrets get "$1")" '{"secret":$secret}'
