{ self, ... }:
{
  imports = [
    self.users.alex.nixosModule

    ../../modules/nixos/rpi4.nix

    ../../modules/nixos/base.nix
    ../../modules/nixos/zsh.nix
    ../../modules/nixos/auto-pressure-gc.nix
    ../../modules/nixos/zram.nix
  ];

  nixpkgs.hostPlatform = "aarch64-linux";
  nix.settings.cores = 2;
  networking.hostName = "bramble";
  time.timeZone = "America/New_York";
}
