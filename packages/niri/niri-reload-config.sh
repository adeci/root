#!/bin/bash
# Because ConfigLoaded has no request ID, serialize helper invocations.
set -uo pipefail

NIRI_BIN='@niri@'
JQ='@jq@'
FLOCK='@flock@'
DEFAULT_CONFIG='@config@'
PACKAGED_NIRI_VERSION='@version@'
EVENT_TIMEOUT_SECONDS=10

error() {
  printf '%s\n' "niri-reload-config: $*" >&2
  exit 1
}

PROGRAM_NAME="${0##*/}"

show_help() {
  printf '%s\n' \
    "usage: $PROGRAM_NAME [--config ABSOLUTE_PATH]" \
    '' \
    'Reload the config bundled with this niri wrapper or a config at an explicit absolute path.'
}

usage() {
  show_help >&2
  exit 2
}

config="$DEFAULT_CONFIG"
case "$#" in
  0) ;;
  1)
    case "$1" in
      -h | --help) show_help; exit 0 ;;
      *) usage ;;
    esac
    ;;
  2)
    [ "$1" = --config ] || usage
    case "$2" in
      /*) config="$2" ;;
      *) error "--config must be an absolute path" ;;
    esac
    ;;
  *) usage ;;
esac

runtime_dir="${XDG_RUNTIME_DIR:-}"
[ -n "$runtime_dir" ] || error 'XDG_RUNTIME_DIR is not set; run this from a graphical user session'
[ -d "$runtime_dir" ] || error "XDG_RUNTIME_DIR is not a directory: $runtime_dir; set it to a runtime directory and retry"

exec 9>"$runtime_dir/niri-reload-config.lock"
"$FLOCK" -n 9 || error 'another niri-reload-config invocation is running; wait for it to finish'

"$NIRI_BIN" validate -c "$config" || error "config validation failed: $config; correct the reported error and retry"

if ! version_output="$("$NIRI_BIN" msg version 2>&1)"; then
  error "could not query the running niri version: $version_output"
fi

compositor_version=''
while IFS= read -r line || [ -n "$line" ]; do
  # Accept an optional Nixpkgs annotation, but compare only the core version.
  line="${line%$'\r'}"
  case "$line" in
    'Compositor version: '*)
      candidate="${line#Compositor version: }"
      [ -z "$compositor_version" ] || error 'multiple compositor versions reported'

      core_version="${candidate%% *}"
      annotation="${candidate#"$core_version"}"
      case "$core_version" in
        '' | *[!0-9A-Za-z._+~-]*) error "malformed compositor version: $candidate" ;;
      esac
      case "$annotation" in
        '') ;;
        ' ('*')')
          annotation="${annotation# (}"
          annotation="${annotation%)}"
          case "$annotation" in
            '' | ' '* | *' ' | *[![:print:]]* | *['()']*) error "malformed compositor version: $candidate" ;;
          esac
          ;;
        *) error "malformed compositor version: $candidate" ;;
      esac
      compositor_version="$core_version"
      ;;
    *[Cc][Oo][Mm][Pp][Oo][Ss][Ii][Tt][Oo][Rr]*[Vv][Ee][Rr][Ss][Ii][Oo][Nn]*)
      error "malformed compositor version field: $line"
      ;;
  esac
done <<EOF
$version_output
EOF

[ -n "$compositor_version" ] || error 'could not parse the compositor version'
[ "$compositor_version" = "$PACKAGED_NIRI_VERSION" ] || error "niri version mismatch: package $PACKAGED_NIRI_VERSION, running compositor $compositor_version; restart the niri session"

coproc EVENT_STREAM {
  exec 9>&-
  "$NIRI_BIN" msg --json event-stream
}
event_pid="$EVENT_STREAM_PID"
exec {event_fd}<&"${EVENT_STREAM[0]}"

cleanup() {
  kill "$event_pid" 2>/dev/null || true
  wait "$event_pid" 2>/dev/null || true
}
trap cleanup EXIT

wait_for_config_loaded() {
  local deadline remaining line result
  deadline=$((SECONDS + EVENT_TIMEOUT_SECONDS))

  while :; do
    remaining=$((deadline - SECONDS))
    [ "$remaining" -gt 0 ] || error 'timed out waiting for ConfigLoaded'

    if ! IFS= read -r -t "$remaining" line <&"$event_fd"; then
      if kill -0 "$event_pid" 2>/dev/null; then
        error 'timed out waiting for ConfigLoaded'
      fi
      wait "$event_pid" || error 'niri event stream failed'
      error 'niri event stream ended before ConfigLoaded'
    fi

    if ! result="$(printf '%s\n' "$line" | "$JQ" -er '
      if type == "object"
        and (keys == ["ConfigLoaded"])
        and (.ConfigLoaded | type == "object")
        and (.ConfigLoaded | keys == ["failed"])
        and (.ConfigLoaded.failed | type == "boolean")
      then
        if .ConfigLoaded.failed then "failed" else "success" end
      else
        "other"
      end
    ')"; then
      error 'malformed event from niri event stream'
    fi

    case "$result" in
      success | failed) CONFIG_LOADED_RESULT="$result"; return ;;
      other) ;;
      *) error 'unexpected event parser result' ;;
    esac
  done
}

# The first ConfigLoaded event reports the previous reload result.
wait_for_config_loaded

"$NIRI_BIN" msg action load-config-file --path "$config" || error "could not request config reload: $config"

wait_for_config_loaded
case "$CONFIG_LOADED_RESULT" in
  success) printf 'niri-reload-config: loaded %s\n' "$config" ;;
  failed) error "niri rejected config: $config" ;;
  *) error 'missing ConfigLoaded result' ;;
esac
