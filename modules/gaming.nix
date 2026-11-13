{
  nixos =
    { pkgs, ... }:
    {
      environment.systemPackages = [
        pkgs.prismlauncher
        pkgs.steam-tui
        pkgs.gamescope
        pkgs.moonlight-qt
      ];
      programs.steam.enable = true;
      programs.steam.gamescopeSession.enable = true;
      programs.steam.extraCompatPackages = [
        pkgs.mangohud
        pkgs.proton-ge-bin
      ];
      programs.gamescope = {
        enable = true;
        capSysNice = true;
      };
    };
}
