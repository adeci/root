{ inputs, ... }:
let
  services = import ../clan-services { inherit inputs; };
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

  clan = {
    meta.name = "adeci";
    meta.domain = "cymric-daggertooth.ts.net";
    inventory = import ../inventory/clan;
    modules = services;
    specialArgs = {
      inherit (inputs) self;
      inherit inputs;
    };
  };
}
