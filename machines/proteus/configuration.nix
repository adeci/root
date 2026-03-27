{
  pkgs,
  self,
  ...
}:
{
  imports = [
    self.users.alex.nixosModule

    ../../modules/nixos/base.nix
    ../../modules/nixos/zsh.nix
    ../../modules/nixos/auto-timezone.nix
    ../../modules/nixos/niri.nix
    ../../modules/nixos/amd-gpu.nix
    ../../modules/nixos/zram.nix
    ../../modules/nixos/keyd.nix
    ../../modules/nixos/steam-deck.nix
  ];

  environment.systemPackages = [
    self.packages.${pkgs.stdenv.hostPlatform.system}.librewolf
  ];

  nix.settings.trusted-users = [
    "root"
    self.users.alex.username
  ];
}
