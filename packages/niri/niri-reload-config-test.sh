#!/usr/bin/env bash
set -euo pipefail

helper_source="$1"
niri_output="$2"
packaged_version="$3"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
runtime_dir="$tmpdir/runtime"
fake_bin="$tmpdir/bin"
mkdir -p "$runtime_dir" "$fake_bin"

printf '#!%s\n' "$BASH" > "$fake_bin/niri"
cat >> "$fake_bin/niri" <<'EOF'
set -euo pipefail

case "$1" in
  validate)
    [ "${FAKE_VALIDATE:-ok}" = fail ] && exit 1
    printf '%s\n' "${3:-}" > "$FAKE_VALIDATE_LOG"
    ;;
  msg)
    case "$2" in
      version)
        if [ "${FAKE_VERSION_OUTPUT+x}" = x ]; then
          printf '%s' "$FAKE_VERSION_OUTPUT"
        else
          printf 'Compositor version: %s\nCLI version: fake\n' "${FAKE_VERSION:-$PACKAGED_VERSION}"
        fi
        ;;
      --json)
        [ "$3" = event-stream ]
        initial="${FAKE_INITIAL:-}"
        [ -n "$initial" ] || initial='{"ConfigLoaded":{"failed":true}}'
        printf '%s\n' "$initial"
        while [ ! -e "$FAKE_ACTION_FILE" ]; do sleep 0.01; done
        case "${FAKE_EVENT:-success}" in
          success) printf '%s\n' '{"ConfigLoaded":{"failed":false}}' ;;
          failed) printf '%s\n' '{"ConfigLoaded":{"failed":true}}' ;;
          malformed) printf '%s\n' 'not json' ;;
          timeout) sleep 2 ;;
        esac
        ;;
      action)
        [ "$3" = load-config-file ]
        [ "$4" = --path ]
        printf '%s\n' "$5" > "$FAKE_ACTION_LOG"
        touch "$FAKE_ACTION_FILE"
        ;;
      *) exit 64 ;;
    esac
    ;;
  *) exit 64 ;;
esac
EOF
chmod +x "$fake_bin/niri"

helper="$tmpdir/niri-reload-config"
cp "$helper_source" "$helper"
sed -i \
  -e "s|^NIRI_BIN=.*|NIRI_BIN='$fake_bin/niri'|" \
  -e 's/^EVENT_TIMEOUT_SECONDS=.*/EVENT_TIMEOUT_SECONDS=1/' \
  "$helper"
chmod +x "$helper"

run_helper() {
  XDG_RUNTIME_DIR="$runtime_dir" \
    FAKE_VALIDATE_LOG="$tmpdir/validate.log" \
    FAKE_ACTION_LOG="$tmpdir/action.log" \
    FAKE_ACTION_FILE="$tmpdir/action" \
    PACKAGED_VERSION="$packaged_version" \
    "$helper" "$@"
}

reset_case() {
  rm -f "$tmpdir/action" "$tmpdir/action.log" "$tmpdir/validate.log"
  unset FAKE_VALIDATE FAKE_VERSION FAKE_VERSION_OUTPUT FAKE_EVENT FAKE_INITIAL
}

expect_success() {
  if ! run_helper "$@"; then
    echo "expected success: $*" >&2
    exit 1
  fi
}

expect_failure() {
  if run_helper; then
    echo "expected failure" >&2
    exit 1
  fi
}

reset_case
FAKE_EVENT=success expect_success
[ "$(cat "$tmpdir/action.log")" = "$niri_output/niri-config.kdl" ]

reset_case
FAKE_VERSION="$packaged_version (Nixpkgs)" expect_success

reset_case
FAKE_INITIAL='{"ConfigLoaded":{"failed":false}}' FAKE_EVENT=failed expect_failure

reset_case
FAKE_EVENT=malformed expect_failure

reset_case
FAKE_EVENT=timeout expect_failure

reset_case
FAKE_VERSION="$packaged_version-mismatch" expect_failure
[ ! -e "$tmpdir/action" ]

reset_case
FAKE_VERSION_OUTPUT="Compositor version: $packaged_version"$'\n'"Compositor version: $packaged_version"$'\n' expect_failure
[ ! -e "$tmpdir/action" ]

reset_case
FAKE_VALIDATE=fail expect_failure
[ ! -e "$tmpdir/action" ]

reset_case
config_with_spaces="$tmpdir/config with spaces.kdl"
touch "$config_with_spaces"
expect_success --config "$config_with_spaces"
[ "$(cat "$tmpdir/validate.log")" = "$config_with_spaces" ]
[ "$(cat "$tmpdir/action.log")" = "$config_with_spaces" ]

reset_case
flock "$runtime_dir/niri-reload-config.lock" sleep 2 &
lock_holder=$!
sleep 0.05
expect_failure
wait "$lock_holder"

unit="$niri_output/share/systemd/user/niri.service"
grep -Fx 'ExecReload=' "$unit"
[ "$(grep -c '^ExecReload=.' "$unit")" = 1 ]
grep -Fx "ExecReload=$niri_output/bin/niri-reload-config" "$unit"
! grep -F 'load-config-file --path' "$unit"
