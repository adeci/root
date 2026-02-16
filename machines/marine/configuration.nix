{ config, ... }:
{

  imports = [
    ../../modules/nixos
  ];

  adeci = {
    base.enable = true;
    dev.enable = true;
    shell.enable = true;
    home-manager.enable = true;
  };

  networking = {
    networkmanager.enable = true;
    hostName = "marine";
  };

  time.timeZone = "America/New_York";

  boot = {
    kernelParams = [
      "consoleblank=60"
      "button.lid_init_state=open"
      "button.lid_event=ignore"
    ];
    initrd.systemd.tpm2.enable = false;
  };

  systemd = {
    targets = {
      sleep.enable = false;
      suspend.enable = false;
      hibernate.enable = false;
      hybrid-sleep.enable = false;
    };
    tpm2.enable = false;
  };

  services = {
    xserver.xkb = {
      layout = "us";
      variant = "";
    };
    logind = {
      settings.Login = {
        HandleLidSwitch = "ignore";
        HandleLidSwitchDocked = "ignore";
        HandleLidSwitchExternalPower = "ignore";
      };
    };
  };

  home-manager.users.alex = {
    imports = [ ./home.nix ];
    home.stateVersion = config.system.stateVersion;
  };

}
