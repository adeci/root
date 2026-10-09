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
    meta.name = "adeci-work";
    meta.domain = "cymric-daggertooth.ts.net";
    inventory = import ../../inventory/clan;
    modules."@adeci/tailscale" = import (inputs.root + "/modules/clan/tailscale");
    # Shared modules see the main flake as self and inputs.
    specialArgs = {
      self = inputs.root;
      inputs = inputs.root.inputs;
      workInputs = inputs;
      workUsers = inputs.self.users;
    };
  };
}
