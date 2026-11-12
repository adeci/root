{ config, inputs, ... }:
let
  services = import ../clan-services { inherit inputs; };
  inherit (config.flake.resources.tailscale) domain;

  # Clan inventory from a machine table: each machine's tags and class, deployed over the tailnet.
  mkInventory =
    {
      domain,
      machines,
      instances,
    }:
    {
      inherit instances;
      machines = builtins.mapAttrs (name: machine: {
        inherit (machine) tags;
        machineClass = machine.class or "nixos";
        deploy.targetHost = "root@${name}.${domain}";
      }) machines;
    };
in
{
  # Machines share the perSystem nixpkgs instance.
  perSystem =
    { pkgs, ... }:
    {
      clan.pkgs = pkgs;
    };

  # For other clans' clan.modules.
  flake.clanServices = services;
  flake.lib.mkInventory = mkInventory;

  clan = {
    meta.name = "adeci";
    meta.domain = domain;
    inventory = mkInventory {
      inherit domain;
      inherit (import ../inventory/inventory.nix) machines;
      instances = import ../inventory/instances.nix;
    };
    modules = services;
    specialArgs = {
      inherit (inputs) self;
      inherit inputs;
    };
  };
}
