{ inputs, pkgs, ... }:
let
  dotpkgs = inputs.adeci-dotpkgs.packages.${pkgs.stdenv.hostPlatform.system};
in
{

  environment.systemPackages = [
    pkgs.atuin
    dotpkgs.starship

    # clan autocompletions
    pkgs.python3Packages.argcomplete
  ];

  # Fish shell enabled system-wide (configuration is in home-manager)
  programs.fish.enable = true;

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };
}
