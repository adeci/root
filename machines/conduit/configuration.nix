{ self, ... }:
{
  imports = with self.modules.nixos; [
    self.users.alex.nixosModule

    base
    zsh
    auto-pressure-gc
    zram
    public-edge
    ntfy-alerts
    ext4-single-disk

    ./modules/zipline
    ./modules/ntfy.nix
  ];

  publicEdge.streams = self.inventory.ingress.streams.conduit;

  services.journald.settings.Journal.SystemMaxUse = "200M";
}
