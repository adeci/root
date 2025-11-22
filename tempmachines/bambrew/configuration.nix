_: {

  networking = {
    networkmanager.enable = true;
    hostName = "bambrew";
  };

  time.timeZone = "America/New_York";

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

}
