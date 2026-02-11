{ inputs, ... }:
let
  pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
  dotpkgs = import ../../../dotpkgs {
    inherit pkgs;
    wrappers = inputs.adeci-wrappers;
  };

  users = import ./users.nix { inherit pkgs dotpkgs; };
  machines = import ./machines.nix;
in
{
  roster = {
    module = {
      name = "@adeci/roster";
      input = "self";
    };
    roles.default = {
      tags.all = { };
      settings = {
        inherit users machines;
        homeManager.module = inputs.home-manager.nixosModules.home-manager;
      };
    };
  };
}
