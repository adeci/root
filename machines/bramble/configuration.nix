{ self, ... }:
{
  imports = with self.modules.nixos; [
    self.users.alex.nixosModule

    rpi4

    base
    zsh
    auto-pressure-gc
    zram
  ];

  nixpkgs.hostPlatform = "aarch64-linux";
  nix.settings.cores = 2;
  networking.hostName = "bramble";
  time.timeZone = "America/New_York";
}
