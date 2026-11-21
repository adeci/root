{
  config,
  inputs,
  lib,
  ...
}:
let
  inherit (config.flake.inventory) appliances router;
  inherit (config.flake.inventory.routeros) admin rollbackMarker;

  # The local port each appliance's API is forwarded to: 187NN for the appliance at x.x.x.NN.
  tunnelPorts = lib.mapAttrs (
    _: appliance: 18700 + lib.toIntBase10 (lib.last (lib.splitString "." appliance.api.address))
  ) appliances;
in
{
  perSystem =
    { pkgs, self', ... }:
    let
      mkTofuWorkspace = import ../tofu-workspace {
        inherit
          inputs
          lib
          pkgs
          self'
          ;
      };

      guardedApply = pkgs.writeShellApplication {
        name = "net-guarded-apply";
        runtimeInputs = [ (pkgs.python3.withPackages (python: [ python.librouteros ])) ];
        runtimeEnv = {
          ADMIN_SECRET = admin.secret;
          ROLLBACK_MARKER = rollbackMarker;
          # Otherwise the plan suggests `tofu apply <planfile>`, which skips the guard.
          TF_IN_AUTOMATION = "1";
        };
        text = ''exec python3 ${./guarded-apply.py} "$@"'';
      };

      rotatePassword = pkgs.writeShellApplication {
        name = "net-rotate-password-on-devices";
        runtimeInputs = [
          (pkgs.python3.withPackages (python: [ python.librouteros ]))
          pkgs.sops
        ]
        # sops needs clan's age plugins to decrypt the secret's previous version.
        ++ map (plugin: pkgs.${plugin}) config.flake.clan.secrets.age.plugins;
        runtimeEnv.ADMIN_SECRET = admin.secret;
        text = ''exec python3 ${./rotate-password.py} "$@"'';
      };
    in
    mkTofuWorkspace {
      name = "network";
      stateKey = "network.tfstate";
      providers = {
        random = pkgs.terraform-providers.hashicorp_random;
        routeros = pkgs.terraform-providers.terraform-routeros_routeros;
      };
      modules = [ ../../terranix/routeros ];
      extraArgs = { inherit tunnelPorts; };
      appPrefix = "net";
      commands = [
        "init"
        "plan"
        "apply"
        "destroy"
        "state"
      ];
      # The router always reaches the appliances' VLAN; the machine this runs on may not.
      tunnel = {
        host = config.flake.clan.inventory.machines.${router.machine}.deploy.targetHost;
        forwards = lib.mapAttrsToList (
          name: appliance:
          "${toString tunnelPorts.${name}}:${appliance.api.address}:${toString appliance.api.port}"
        ) appliances;
      };
      # `net-apply <device>`: bring up a blank appliance while others are unreachable or blank.
      applyAlone = lib.mapAttrs (name: _: "routeros.${name}") appliances;
      # Changed devices roll back unless every device answers afterwards.
      apply = guardedApply;
      scripts.state-rm-device = ./net-state-rm-device.sh;
      scripts.rotate-password = ./net-rotate-password.sh;
      runtimeInputs = [
        pkgs.jq
        rotatePassword
      ];
    };
}
