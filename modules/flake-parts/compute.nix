{ config, lib, ... }:
let
  inventory = import ../../inventory/compute;
  clanMachines = import ../../inventory/clan/machines.nix;

  clanTargetFor = name: clanMachines.${name}.deploy.targetHost or "root@${name}";

  # Root adapter: microcompute is Clan-agnostic, so this module resolves our
  # Clan machine deploy targets into the generic host/guest SSH target fields.
  instances = lib.mapAttrs (
    name: instance: instance // { targetHost = clanTargetFor name; }
  ) inventory.instances;

  hosts = lib.mapAttrs (name: host: host // { targetHost = clanTargetFor name; }) inventory.hosts;
in
{
  config = {
    microcompute = {
      inherit instances hosts;
      inherit (inventory) assignments networks;
    };

    # Compatibility alias for existing root callers such as Janus DHCP facts.
    flake.compute = config.flake.lib.microcompute;
  };
}
