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
    # Shared modules consume the parent package/input context, not the work flake.
    specialArgs = {
      self = inputs.root;
      inputs = inputs.root.inputs;
      workInputs = inputs;
      workUsers = inputs.self.users;
    };
  };
}
