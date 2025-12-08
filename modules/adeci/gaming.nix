{ pkgs, ... }:
{

  environment.systemPackages = with pkgs; [
    prismlauncher
    steam-tui
  ];

  programs.steam.enable = true;
  programs.steam.extraCompatPackages = with pkgs; [
    mangohud
    proton-ge-bin
  ];

}
