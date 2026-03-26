{ inputs, ... }:
{
  clan = {
    meta.name = "adeci";
    meta.domain = "cymric-daggertooth.ts.net";
    inventory = import ../../inventory {
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
