{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.adeci.aerospace;
  kitty-home = pkgs.writeShellScript "kitty-home" ''exec kitty -d "$HOME"'';
  kitty-here = pkgs.writeShellScript "kitty-here" (builtins.readFile ./kitty-here.sh);
in
{
  options.adeci.aerospace.enable = lib.mkEnableOption "Aerospace window manager configuration";
  config = lib.mkIf cfg.enable {
    home.file.".config/aerospace/aerospace.toml".text =
      builtins.replaceStrings
        [ "@KITTY_HOME@" "@KITTY_HERE@" ]
        [ (toString kitty-home) (toString kitty-here) ]
        (builtins.readFile ./config.toml);
  };
}
