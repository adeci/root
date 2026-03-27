{
  self,
  ...
}:
{
  imports = [
    self.users.alex.nixosModule

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

  nix.settings.trusted-users = [
    "root"
    self.users.alex.username
  ];
}
