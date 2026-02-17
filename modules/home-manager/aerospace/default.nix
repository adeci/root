{
  config,
  lib,
  ...
}:
let
  cfg = config.adeci.aerospace;
in
{
  options.adeci.aerospace.enable = lib.mkEnableOption "Aerospace window manager configuration";
  config = lib.mkIf cfg.enable {
    home.file.".config/aerospace/aerospace.toml".source = ./config.toml;
  };
}
