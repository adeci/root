{ self, ... }:
{
  imports = with self.modules.nixos; [
    self.users.alex.nixosModule

    base
    zsh
    auto-pressure-gc
    zram
    secure-boot-luks
    initrd-ssh-unlock

    ./modules/mandate
  ];
}
