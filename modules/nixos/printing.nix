{ config, lib, ... }:
let
  cfg = config.adeci.printing;
in
{
  options.adeci.printing.enable = lib.mkEnableOption "printing (CUPS, Avahi)";
  config = lib.mkIf cfg.enable {
    services.printing = {
      enable = true;
      browsedConf = ''
        CreateIPPPrinterQueues Driverless
      '';
    };
    services.avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };
  };
}
