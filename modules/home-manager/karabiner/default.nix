{
  config,
  lib,
  ...
}:
let
  cfg = config.adeci.karabiner;
in
{
  options.adeci.karabiner.enable = lib.mkEnableOption "Karabiner Elements configuration";
  config = lib.mkIf cfg.enable {
    home.file.".config/karabiner/karabiner.json".source = ./config.json;
  };
}
