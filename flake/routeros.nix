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

      tofu = import ./tofu-workspace.nix {
        inherit pkgs clan-cli;
        workspace = "network";
        tfConfig = netTfConfig;
      };
    in
    {
      packages = {
        net-init = tofu.command "net-init" "init";
        net-plan = tofu.command "net-plan" "plan";
        net-apply = tofu.command "net-apply" "apply";
        net-destroy = tofu.command "net-destroy" "destroy";
        net-state = tofu.command "net-state" "state";

        net-state-rm-device = tofu.script "net-state-rm-device" ''
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
      };
    };
}
