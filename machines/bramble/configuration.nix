{ self, ... }:
{
  imports = [
    self.users.alex.nixosModule

    ../../modules/nixos/rpi4.nix

    ../../modules/nixos/base.nix
    ../../modules/nixos/zsh.nix
  ];

  nixpkgs.hostPlatform = "aarch64-linux";
  networking.hostName = "bramble";
  time.timeZone = "America/New_York";
}
