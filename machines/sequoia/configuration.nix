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
    ../../modules/nixos/cloudflared.nix
    ./modules/matrix-synapse.nix
    ./modules/vaultwarden.nix
    ./modules/opencrow
    ./modules/atuin.nix
  ];
}
