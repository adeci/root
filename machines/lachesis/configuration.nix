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

  # The initrd only needs the wired port for ssh; facter would also add Wi-Fi and its firmware.
  hardware.facter.detected.boot.initrd.networking.kernelModules = [ "e1000e" ];
}
