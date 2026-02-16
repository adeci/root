{
  config,
  lib,
  pkgs,
  dotpkgs,
  ...
}:
let
  cfg = config.adeci.shell-tools;
in
{
  options.adeci.shell-tools.enable = lib.mkEnableOption "shell tools (starship, atuin, zoxide, direnv)";
  config = lib.mkIf cfg.enable {
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
  };
}
