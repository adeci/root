{ self, ... }:
{
  imports = with self.modules.nixos; [
    self.users.alex.nixosModule

    base
    zsh
    auto-pressure-gc
    zram
    ext4-single-disk

    ./modules/router
  ];
}
