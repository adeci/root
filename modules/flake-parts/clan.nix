{ inputs, ... }:
{
  perSystem =
    { system, ... }:
    {
      clan.pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    };

  clan = {
    meta.name = "adeci";
    meta.domain = "cymric-daggertooth.ts.net";
    inventory = import ../../inventory/clan {
      inherit (inputs.nixpkgs) lib;
      inherit inputs;
    };
    modules = import ../clan { inherit inputs; };
    specialArgs = {
      inherit (inputs) self;
      inherit inputs;
    };
  };
}
