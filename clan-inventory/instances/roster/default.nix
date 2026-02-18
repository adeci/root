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
          base = "home-manager/profiles/base.nix";
          desktop = "home-manager/profiles/desktop.nix";
          darwin-desktop = "home-manager/profiles/darwin-desktop.nix";
          shopify = "home-manager/profiles/shopify.nix";
          llm-tools = "home-manager/profiles/llm-tools.nix";
        };
        darwinHomeStateVersion = "25.11";
        users = import ./users.nix;
        machines = import ./machines.nix;
      };
    };
  };
}
