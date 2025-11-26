_: {

  networking = {
    networkmanager.enable = true;
    hostName = "spud";
  };

  time.timeZone = "America/New_York";

  imports = [
    ../../modules/adeci/all.nix
    ../../modules/adeci/dev.nix
    ../../modules/adeci/shell.nix
  ];

}
