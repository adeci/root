{ inputs, ... }:
let
  pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
  dotpkgs = inputs.adeci-dotpkgs.packages.${pkgs.stdenv.hostPlatform.system};

  users = import ./users.nix { inherit pkgs dotpkgs; };
  machines = import ./machines.nix;
in
{
  roster = {
    module = {
      name = "@onix/roster";
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
