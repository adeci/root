{ self, ... }:
{
  imports = [
    self.users.alex.nixosModule

    ../../modules/nixos/base.nix
    ../../modules/nixos/zsh.nix
    ../../modules/nixos/llm-tools.nix
    ../../modules/nixos/auto-timezone.nix
    ../../modules/nixos/desktop.nix
    ../../modules/nixos/amd-gpu.nix
    ../../modules/nixos/zram.nix
    ../../modules/nixos/keyd.nix
    ../../modules/nixos/steam-deck.nix
  ];

  environment.systemPackages = [
  ];

  nix.settings.trusted-users = [
    "root"
    self.users.alex.username
  ];
}
