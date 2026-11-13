{
  config,
  inputs,
  self,
  ...
}:
let
  services = import ../clan-services { inherit inputs; };
  inherit (config.flake.inventory) tailnet;

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
  imports = [ inputs.clan-core.flakeModules.default ];

  perSystem =
    { pkgs, system, ... }:
    {
      # One nixpkgs for machines, packages and tests.
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      clan.pkgs = pkgs;
    };

  # For other clans' clan.modules.
  flake.clanServices = services;
  flake.lib.mkInventory = mkInventory;

  # Each machines/<name>/ is a machine: clan imports its configuration.nix and disko.nix.
  clan = {
    meta.name = "adeci";
    meta.domain = tailnet.domain;
    inventory = mkInventory {
      inherit (tailnet) domain;
      inherit (config.flake.inventory) machines;
      instances = config.flake.inventory.clanInstances;
    };
    modules = services;
    # Every module gets self and inputs.
    specialArgs = { inherit self inputs; };
  };
}
