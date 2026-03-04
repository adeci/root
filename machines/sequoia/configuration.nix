{ ... }:
{
  networking = {
    hostName = "sequoia";
    networkmanager.enable = true;
  };

  home-manager.users.alex = import ./home.nix;

  time.timeZone = "America/New_York";

  imports = [
    ../../modules/nixos/home-manager.nix

    ../../modules/nixos/base.nix
    ../../modules/nixos/dev.nix
    # ./modules/buildbot.nix  # moved to leviathan (master + worker)
  ];
}
