{ ... }:
{
  networking = {
    hostName = "sequoia";
    networkmanager.enable = true;
  };

  time.timeZone = "America/New_York";

  imports = [
    ../../modules/nixos
  ];

  adeci = {
    base.enable = true;
    dev.enable = true;
    shell.enable = true;
  };
}
