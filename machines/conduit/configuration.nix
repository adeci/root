{ self, ... }:
{

  imports = [
    self.users.alex.nixosModule

    ../../modules/nixos/base.nix
    ../../modules/nixos/zsh.nix
    ../../modules/nixos/auto-pressure-gc.nix
    ../../modules/nixos/zram.nix
    ../../modules/nixos/public-edge.nix

    ./modules/zipline.nix
  ];

  time.timeZone = "America/New_York";

  services.journald.settings.Journal.SystemMaxUse = "200M";

}
