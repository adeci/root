{
  self,
  ...
}:
{
  imports = with self.modules.nixos; [
    self.users.alex.nixosModule
    base
    zsh
    auto-pressure-gc
    zram
    secure-boot-luks
    ./modules/mandate.nix
  ];

  # Onboard Intel NIC, needed in the initrd for SSH unlock.
  boot.initrd.availableKernelModules = [ "e1000e" ];

  time.timeZone = "America/New_York";
}
