{ config, ... }:
{

  networking = {
    networkmanager.enable = true;
    hostName = "spud";
  };

  time.timeZone = "America/New_York";

  imports = [
    ../../nix-modules/all.nix
    ../../nix-modules/dev.nix
    ../../nix-modules/shell.nix
    ../../nix-modules/home-manager.nix
  ];

  home-manager.users.alex = {
    imports = [ ./home.nix ];
    home.stateVersion = config.system.stateVersion;
  };

}
