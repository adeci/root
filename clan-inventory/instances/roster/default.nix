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
        users = import ./users.nix;
        machines = import ./machines.nix;
      };
    };
  };
}
