{ self, ... }:
{

  imports = [
    self.users.alex.nixosModule

    ../../modules/nixos/base.nix
    ../../modules/nixos/zsh.nix
    ../../modules/nixos/auto-pressure-gc.nix
    ../../modules/nixos/zram.nix
    ../../modules/nixos/cloudflared.nix
    ../../modules/nixos/public-edge.nix

    ./modules/pressroom.nix
  ];

  time.timeZone = "America/New_York";

  services.journald.extraConfig = ''
    SystemMaxUse=200M
  '';

}
