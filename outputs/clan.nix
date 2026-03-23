{ inputs, ... }:
let
  clan = inputs.clan-core.lib.clan {
    inherit (inputs) self;
    meta.name = "adeci";
    meta.domain = "cymric-daggertooth.ts.net";
    inventory = import ../inventory {
      inherit (inputs.nixpkgs) lib;
      inherit inputs;
    };
    modules = import ../modules/clan { inherit inputs; };
    specialArgs = {
      inherit (inputs) self;
      inherit inputs;
    };
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
    clanModules = import ../modules/clan { inherit inputs; };
  };
}
