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

        # ── Bootstrap ──────────────────────────────────────────────
        routeros-bootstrap = linuxOnly (
          pkgs.writeShellApplication {
            name = "routeros-bootstrap";
            runtimeInputs = [
              pkgs.iproute2
              clan-cli
            ];
            text = # bash
              ''
                exec ${lib.getExe pkgs.python3} ${../terranix/routeros/bootstrap.py} "$@"
              '';
          }
        );
      };
    };
}
