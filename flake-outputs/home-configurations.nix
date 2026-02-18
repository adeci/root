# Standalone home-manager configuration for non-NixOS/non-Darwin machines.
# Use `home-manager switch --flake .#alex` on any Linux box without NixOS.
# For Clan-managed machines, HM is configured via roster profiles instead.
{ inputs, self, ... }:
let
  pkgs = import inputs.nixpkgs {
    system = "x86_64-linux";
    config.allowUnfree = true;
  };
in
{
  flake.homeConfigurations.alex = inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    extraSpecialArgs = { inherit inputs self; };
    modules = [
      ../modules/home-manager
      {
        adeci = {
          base-tools.enable = true;
          shell-tools.enable = true;
          dev-tools.enable = true;
          fish.enable = true;
          git.enable = true;
        };
        home.username = "alex";
        home.homeDirectory = "/home/alex";
        home.stateVersion = "24.11";
      }
    ];
  };
}
