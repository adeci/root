{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  cfg = config.adeci.shell-tools;
  packages = self.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  options.adeci.shell-tools.enable = lib.mkEnableOption "shell tools (starship, atuin, zoxide, direnv)";
  config = lib.mkIf cfg.enable {
    home.packages = [
      packages.starship
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
