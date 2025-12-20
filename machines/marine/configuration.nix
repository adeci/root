_: {

  imports = [
    ../../modules/adeci/all.nix
    ../../modules/adeci/dev.nix
    ../../modules/adeci/shell.nix
  ];

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

}
