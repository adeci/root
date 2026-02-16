{ config, ... }:
{

  networking = {
    networkmanager.enable = true;
    hostName = "spud";
  };

  time.timeZone = "America/New_York";

  imports = [
    ../../modules/nixos
  ];

  adeci = {
    base.enable = true;
    dev.enable = true;
    shell.enable = true;
    home-manager.enable = true;
  };

  home-manager.users.alex = {
    imports = [ ./home.nix ];
    home.stateVersion = config.system.stateVersion;
  };

}
