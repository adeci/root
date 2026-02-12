{ pkgs, inputs, ... }:
let
  dotpkgs = import ../../dotpkgs { inherit pkgs inputs; };
in
{
  imports = [
    ../fish.nix
  ];

  home.packages = [
    dotpkgs.starship.wrapper
    pkgs.python3Packages.argcomplete
  ];

  programs.atuin.enable = true;

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.direnv = {
    enable = true;
  };
}
