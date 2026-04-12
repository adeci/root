# RouterOS network infrastructure — separate Terraform workspace
# Bootstrap + deploy tools for MikroTik devices.
# Linux-only (RouterOS provider + networking tools).
{
  inputs,
  lib,
  ...
}:
{
  perSystem =
    {
      pkgs,
      system,
      self',
      inputs',
      ...
    }:
    let
      inherit (inputs'.clan-core.packages) clan-cli;

      # Network workspace uses the same B2 backend but a separate state key
      netTfConfig = inputs.terranix.lib.terranixConfiguration {
        inherit system;
        modules = [
          ../terranix/backend.nix
          ../terranix/routeros
          {
            terraform.backend.s3.key = lib.mkForce "network.tfstate";
          }
        ];
        extraArgs = {
          inherit (inputs) self;
          inherit self' inputs inputs';
        };
      };

      netTfSetup = # bash
        ''
          cd "$(git rev-parse --show-toplevel)"
          mkdir -p .terraform/network
          cd .terraform/network

          AWS_ACCESS_KEY_ID=$(clan secrets get b2-key-id)
          AWS_SECRET_ACCESS_KEY=$(clan secrets get b2-application-key)
          AWS_REQUEST_CHECKSUM_CALCULATION=when_required
          AWS_RESPONSE_CHECKSUM_VALIDATION=when_required
          export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
          export AWS_REQUEST_CHECKSUM_CALCULATION AWS_RESPONSE_CHECKSUM_VALIDATION

          install -m644 ${netTfConfig} config.tf.json
        '';

      linuxOnly =
        pkg:
        pkg
        // {
          meta = (pkg.meta or { }) // {
            platforms = lib.platforms.linux;
          };
        };

      netCommand =
        name: cmd:
        linuxOnly (
          pkgs.writeShellApplication {
            inherit name;
            runtimeInputs = [
              pkgs.gitMinimal
              pkgs.opentofu
              clan-cli
            ];
            text = # bash
              ''
                ${netTfSetup}
                tofu ${cmd} "$@"
              '';
          }
        );
    in
    {
      packages = lib.optionalAttrs pkgs.stdenv.isLinux {
        # ── Network Terraform commands ──────────────────────────────
        net-init = netCommand "net-init" "init";
        net-plan = netCommand "net-plan" "plan";
        net-apply = netCommand "net-apply" "apply";
        net-destroy = netCommand "net-destroy" "destroy";
        net-state = netCommand "net-state" "state";

        # Remove all terraform resources for a device in one session
        net-state-rm-device = linuxOnly (
          pkgs.writeShellApplication {
            name = "net-state-rm-device";
            runtimeInputs = [
              pkgs.gitMinimal
              pkgs.opentofu
              clan-cli
            ];
            text = # bash
              ''
                ${netTfSetup}
                if [[ $# -eq 0 ]]; then
                  echo "Usage: net-state-rm-device <device-name> [device-name ...]"
                  exit 1
                fi
                all_state="$(tofu state list 2>/dev/null)"
                resources=()
                for device in "$@"; do
                  mapfile -t matched < <(echo "$all_state" | grep "$device")
                  resources+=("''${matched[@]}")
                done
                if [[ ''${#resources[@]} -eq 0 ]]; then
                  echo "No resources found matching: $*"
                  exit 0
                fi
                echo "Removing ''${#resources[@]} resources matching: $*"
                for r in "''${resources[@]}"; do
                  echo "  $r"
                done
                echo ""
                read -rp "Continue? [y/N] " confirm
                if [[ "$confirm" != "y" ]]; then
                  echo "Aborted."
                  exit 0
                fi
                tofu state rm "''${resources[@]}"
                echo "Done."
              '';
          }
        );

        # ── Netinstall (one-shot device provisioning) ────────────────
        routeros-netinstall-cap-ax = import ../terranix/routeros/netinstall-cap-ax.nix {
          inherit pkgs clan-cli;
        };
        routeros-netinstall-crs328 = import ../terranix/routeros/netinstall-crs328.nix {
          inherit pkgs clan-cli;
        };
        routeros-netinstall-crs310 = import ../terranix/routeros/netinstall-crs310.nix {
          inherit pkgs clan-cli;
        };

      };
    };
}
