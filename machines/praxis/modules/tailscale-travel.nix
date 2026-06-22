{ pkgs, ... }:
let
  tailscaleTravel = pkgs.writeShellApplication {
    name = "tailscale-travel";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.gawk
      pkgs.gnugrep
      pkgs.tailscale
    ];
    text = ''
      default_exit_node=sequoia

      usage() {
        cat <<EOF
      Usage: tailscale-travel [status|away|home|list|check] [exit-node|peer...]

        tailscale-travel               Show current travel routing state
        tailscale-travel status        Show current travel routing state
        tailscale-travel away [node]   Use an exit node, default: $default_exit_node
        tailscale-travel home          Clear exit node and stop accepting subnet routes
        tailscale-travel list          Show available exit nodes
        tailscale-travel check [peer]  Check public IP and peer reachability
      EOF
      }

      pref_enabled() {
        if tailscale debug prefs | grep -Eq "\"$1\"[[:space:]]*:[[:space:]]*true"; then
          echo on
        else
          echo off
        fi
      }

      backend_state() {
        tailscale status --json | awk -F'"' '/"BackendState":/ { print $4; found = 1; exit } END { if (!found) print "unknown" }'
      }

      selected_exit_node() {
        tailscale exit-node list | awk '
          $NF == "selected" {
            host = $2
            sub(/\..*/, "", host)
            print host
            found = 1
          }
          END { if (!found) print "off" }
        '
      }

      this_node() {
        tailscale status --self | awk 'NR == 1 { print $2 }'
      }

      status() {
        echo "state:       $(backend_state)"
        echo "exit node:   $(selected_exit_node)"
        echo "subnets:     $(pref_enabled RouteAll)"
        echo "local LAN:   $(pref_enabled ExitNodeAllowLANAccess)"
        echo "this node:   $(this_node)"
      }

      public_ip() {
        curl --fail --silent --show-error --max-time 8 https://ifconfig.me || echo unavailable
      }

      check() {
        shift

        status

        echo
        echo "public IP:   $(public_ip)"

        if [ "$#" -eq 0 ]; then
          exit_node=$(selected_exit_node)
          if [ "$exit_node" = "off" ]; then
            return 0
          fi
          set -- "$exit_node"
        fi

        echo
        echo "peers:"
        failed=0
        for peer in "$@"; do
          line=$(tailscale ping --timeout=4s --c 1 "$peer" 2>&1 | grep -m1 '^pong from' || true)
          if [ -n "$line" ]; then
            echo "  ok    $peer    $line"
          else
            echo "  fail  $peer"
            failed=1
          fi
        done

        exit "$failed"
      }

      case "''${1:-status}" in
        status)
          status
          ;;
        away)
          exit_node="''${2:-$default_exit_node}"
          sudo tailscale set \
            --exit-node="$exit_node" \
            --exit-node-allow-lan-access=true \
            --accept-routes=true
          status
          ;;
        home)
          sudo tailscale set \
            --exit-node= \
            --accept-routes=false
          status
          ;;
        list)
          tailscale exit-node list
          ;;
        check)
          check "$@"
          ;;
        help|-h|--help)
          usage
          ;;
        *)
          usage >&2
          exit 2
          ;;
      esac
    '';
  };
in
{
  environment.systemPackages = [ tailscaleTravel ];
}
