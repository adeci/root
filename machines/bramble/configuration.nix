{ self, ... }:
{
  imports = with self.modules.nixos; [
    raspberry-pi-4

    self.users.alex.nixosModule

    base
    zsh
    auto-pressure-gc
    zram
  ];

  nixpkgs.hostPlatform = "aarch64-linux";
  nix.settings.cores = 2;
}
