{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.adeci.gaming;
in
{
  options.adeci.gaming.enable = lib.mkEnableOption "gaming (Steam, Gamescope, PrismLauncher)";
  config = lib.mkIf cfg.enable {
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
  };
}
