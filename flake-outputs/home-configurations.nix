{ inputs, ... }:
let
  pkgs = import inputs.nixpkgs {
    system = "x86_64-linux";
    config.allowUnfree = true;
  };
  dotpkgs = import ../dotpkgs { inherit pkgs inputs; };
in
{
  flake.homeConfigurations.alex = inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    extraSpecialArgs = { inherit inputs dotpkgs; };
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
