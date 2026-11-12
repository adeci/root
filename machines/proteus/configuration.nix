{ self, ... }:
{
  imports = with self.modules.nixos; [
    self.users.alex.nixosModule

    base
    zsh
    auto-pressure-gc
    auto-timezone
    desktop
    librewolf
    niri
    noctalia
    amd-gpu
    zram
    keyd
    steam-deck
  ];

  boot.loader.grub.configurationLimit = 5;
}
