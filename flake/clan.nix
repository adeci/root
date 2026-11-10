{ inputs, ... }:
{
  # Machines use the same nixpkgs instance as the packages (flake/packages.nix).
  perSystem =
    { pkgs, ... }:
    {
      clan.pkgs = pkgs;
    };

  clan = {
    meta.name = "adeci";
    meta.domain = "cymric-daggertooth.ts.net";
    inventory = import ../inventory/clan {
      inherit (inputs.nixpkgs) lib;
      inherit inputs;
    };
    modules = import ../clan-services { inherit inputs; };
    specialArgs = {
      inherit (inputs) self;
      inherit inputs;
    };
  };
}
