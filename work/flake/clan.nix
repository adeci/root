{ inputs, ... }:
let
  inherit (inputs.root.inventory.tailnet) domain;
in
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
    meta.name = "adeci-work";
    meta.domain = domain;
    inventory = inputs.root.lib.mkInventory {
      inherit domain;
      machines = import ../inventory/machines.nix;
      instances = import ../inventory/clan-instances.nix;
    };
    modules."@adeci/tailscale" = inputs.root.clanServices."@adeci/tailscale";
    # Shared modules see the main flake as self and inputs.
    specialArgs = {
      self = inputs.root;
      inputs = inputs.root.inputs;
      workInputs = inputs;
    };
  };
}
