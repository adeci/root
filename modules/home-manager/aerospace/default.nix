{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.adeci.aerospace;
  kitty-here = pkgs.writeShellScript "kitty-here" (builtins.readFile ./kitty-here.sh);
in
{
  options.adeci.aerospace.enable = lib.mkEnableOption "Aerospace window manager configuration";
  config = lib.mkIf cfg.enable {
    home.file.".config/aerospace/aerospace.toml".text =
      builtins.replaceStrings [ "@KITTY_HERE@" ] [ (toString kitty-here) ]
        (builtins.readFile ./config.toml);
  };
}
