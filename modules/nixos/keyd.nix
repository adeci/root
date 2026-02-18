{
  config,
  lib,
  ...
}:
let
  cfg = config.adeci.keyd;
in
{
  options.adeci.keyd.enable = lib.mkEnableOption "keyd dual-function keys";
  config = lib.mkIf cfg.enable {
    services.keyd = {
      enable = true;
      keyboards.default = {
        ids = [ "*" ];
        settings.main.capslock = "overload(control, esc)";
      };
    };
  };
}
