{ inputs, ... }:
let
  clan = inputs.clan-core.lib.clan {
    self = inputs.self;
    meta.name = "adeci";
    meta.domain = "adeci";
    inventory = import ./clan-inventory {
      lib = inputs.nixpkgs.lib;
      inherit inputs;
    };
    modules = import ./clan-services { };
    specialArgs = { inherit inputs; };
  };
in
{
  flake = {
    inherit (clan.config)
      nixosConfigurations
      darwinConfigurations
      nixosModules
      clanInternals
      ;
    clan = clan.config;
    clanModules = import ./clan-services { };
  };
}
