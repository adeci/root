{ ... }:
{
  roster = {
    module = {
      name = "@adeci/roster";
      input = "self";
    };
    roles.default = {
      tags.all = { };
      settings = {
        homeManagerProfiles = {
          base = [
            "base-tools"
            "shell-tools"
            "dev-tools"
            "fish"
            "git"
          ];
          desktop = [ "desktop" ];
          darwin-desktop = [
            "kitty"
            "karabiner"
            "aerospace"
          ];
        };
        users = import ./users.nix;
        machines = import ./machines.nix;
      };
    };
  };
}
