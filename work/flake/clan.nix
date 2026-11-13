{ inputs, ... }:
let
  inherit (inputs.root.inventory.tailnet) domain;
in
{
  imports = [ inputs.clan-core.flakeModules.default ];

  # Each machines/<name>/ is a machine: clan imports its configuration.nix and disko.nix.
  clan = {
    meta.name = "adeci-work";
    meta.domain = domain;
    inventory = inputs.root.lib.mkInventory {
      inherit domain;
      machines = import ../inventory/machines.nix;
      instances = import ../inventory/clan-instances.nix;
    };
    modules."@adeci/tailscale" = inputs.root.clanServices."@adeci/tailscale";
    # The main clan's nixpkgs.
    inherit (inputs.root.clan) pkgsForSystem;
    # As in the main clan, plus this flake as work.
    specialArgs = {
      self = inputs.root;
      inherit (inputs.root) inputs;
      work = inputs.self;
    };
  };
}
