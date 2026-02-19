_: {
  roster = {
    module = {
      name = "@adeci/roster";
      input = "self";
    };
    roles.default = {
      tags.all = { };
      settings = {
        homeManagerProfiles = {
          base = "profiles/home-manager/base.nix";
          desktop = "profiles/home-manager/desktop.nix";
          darwin-desktop = "profiles/home-manager/darwin-desktop.nix";
          shopify = "profiles/home-manager/shopify.nix";
          llm-tools = "profiles/home-manager/llm-tools.nix";
        };
        darwinHomeStateVersion = "25.11";
        users = import ./users.nix;
        machines = import ./machines.nix;
      };
    };
  };
}
