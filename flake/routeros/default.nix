{
  config,
  inputs,
  lib,
  ...
}:
let
  inherit (config.flake.inventory) appliances router;

  # The local port each appliance's API is forwarded to: 187NN for the appliance at x.x.x.NN.
  tunnelPorts = lib.mapAttrs (
    _: appliance: 18700 + lib.toIntBase10 (lib.last (lib.splitString "." appliance.api.address))
  ) appliances;
in
{
  perSystem =
    { pkgs, ... }:
    let
      mkTofuWorkspace = import ../tofu-workspace { inherit inputs lib pkgs; };
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
      # A blank appliance comes up on its own while the others are unreachable or blank.
      applyAlone = lib.mapAttrs (name: _: "routeros.${name}") appliances;
      scripts.state-rm-device = ./net-state-rm-device.sh;
      runtimeInputs = [ pkgs.jq ];
    };
}
