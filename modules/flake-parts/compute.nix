{ config, lib, ... }:
let
  raw = import ../../inventory/compute;
  clanMachines = import ../../inventory/clan/machines.nix;

  targetFor = name: clanMachines.${name}.deploy.targetHost or "root@${name}";

  instances = lib.mapAttrs (
    name: instance: instance // { targetHost = targetFor name; }
  ) raw.instances;
  hosts = lib.mapAttrs (name: host: host // { targetHost = targetFor name; }) raw.hosts;
in
{
  config = {
    microcompute = {
      inherit instances hosts;
      inherit (raw) assignments networks;
    };

    flake.compute = config.flake.lib.microcompute;
  };
}
