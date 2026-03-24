{
  config,
  ...
}:
{
  imports = [
    ../../modules/nixos/home-manager.nix

    ../../modules/nixos/base.nix
    ../../modules/nixos/auto-timezone.nix
    ../../modules/nixos/niri.nix
    ../../modules/nixos/amd-gpu.nix
    ../../modules/nixos/zram.nix
    ../../modules/nixos/keyd.nix
    ../../modules/nixos/steam-deck.nix
  ];

  home-manager.users.alex = import ./home.nix;

  networking.hostName = "proteus";

  nix.settings.trusted-users = [
    "root"
    config.adeci.primaryUser
  ];
}
