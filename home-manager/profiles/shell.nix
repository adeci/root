{ pkgs, inputs, ... }:
let
  dotpkgs = import ../../dotpkgs {
    inherit pkgs;
    wrappers = inputs.adeci-wrappers;
    nixvim = inputs.nixvim;
  };
in
{
  imports = [
    ../fish.nix
  ];

  home.packages = [
    dotpkgs.starship
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
