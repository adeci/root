{ config, lib, ... }:
let
  cfg = config.adeci.dev;
in
{
  options.adeci.dev.enable = lib.mkEnableOption "development tools (direnv)";
  config = lib.mkIf cfg.enable {
    programs.direnv.enable = true;
  };
}
