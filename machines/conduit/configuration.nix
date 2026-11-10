{ self, ... }:
{

  imports = with self.modules.nixos; [
    self.users.alex.nixosModule

    base
    zsh
    auto-pressure-gc
    zram
    public-edge

    ./modules/zipline.nix
  ];

  time.timeZone = "America/New_York";

  services.journald.settings.Journal.SystemMaxUse = "200M";

}
