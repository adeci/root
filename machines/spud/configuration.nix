_: {

  networking = {
    networkmanager.enable = true;
    hostName = "spud";
  };

  time.timeZone = "America/New_York";

  imports = [
    ../../nix-modules/all.nix
    ../../nix-modules/dev.nix
    ../../nix-modules/shell.nix
  ];

}
