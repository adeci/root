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

  publicEdge.streams = self.inventory.ingress.streams.conduit;

  time.timeZone = "America/New_York";

  services.journald.settings.Journal.SystemMaxUse = "200M";

}
