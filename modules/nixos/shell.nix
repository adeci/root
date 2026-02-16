{ config, lib, ... }:
let
  cfg = config.adeci.shell;
in
{
  options.adeci.shell.enable = lib.mkEnableOption "Fish shell (system-wide login shell)";
  config = lib.mkIf cfg.enable {
    programs.fish.enable = true;
  };
}
