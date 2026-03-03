{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    prismlauncher
    steam-tui
    gamescope
  ];
  programs.steam.enable = true;
  programs.steam.gamescopeSession.enable = true;
  programs.steam.extraCompatPackages = with pkgs; [
    mangohud
    proton-ge-bin
  ];
  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };
}
