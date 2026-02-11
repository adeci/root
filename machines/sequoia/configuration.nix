_: {
  networking = {
    hostName = "sequoia";
    networkmanager.enable = true;
  };

  time.timeZone = "America/New_York";

  imports = [
    ../../nix-modules/all.nix
    ../../nix-modules/dev.nix
    ../../nix-modules/shell.nix
  ];
}
