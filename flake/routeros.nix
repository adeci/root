{
  inputs,
  lib,
  ...
}:
let
  routerosAdmin = {
    user = "admin";
    secret = "routeros-password";
  };
in
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
          inherit
            self'
            inputs
            inputs'
            routerosAdmin
            ;
        };
      };

      tofu = import ./tofu-workspace.nix {
        inherit pkgs clan-cli;
        workspace = "network";
        tfConfig = netTfConfig;
      };

      tofuApps = {
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

      # Process substitution keeps the password off argv and out of any file of our own.
      netinstallApps = lib.mapAttrs' (
        name: package:
        let
          app = "net-netinstall-${lib.removePrefix "routeros-netinstall-" name}";
        in
        lib.nameValuePair app (
          pkgs.writeShellApplication {
            name = app;
            runtimeInputs = [ clan-cli ];
            text = ''
              exec ${lib.getExe package} \
                --admin-user ${lib.escapeShellArg routerosAdmin.user} \
                --admin-password-file <(clan secrets get ${lib.escapeShellArg routerosAdmin.secret}) \
                "$@"
            '';
          }
        )
      ) (lib.filterAttrs (name: _: lib.hasPrefix "routeros-netinstall-" name) self'.packages);
    in
    {
      apps = lib.mapAttrs (_: program: { inherit program; }) (tofuApps // netinstallApps);
    };
}
