{
  self,
  ...
}:
{
  imports = [
    self.users.alex.nixosModule
    ../../modules/nixos/base.nix
    ../../modules/nixos/zsh.nix
    ../../modules/nixos/auto-pressure-gc.nix
    ../../modules/nixos/zram.nix
    ../../modules/nixos/secure-boot-luks.nix
    ./modules/mandate.nix
    ./modules/ssh.nix
  ];

  # Onboard Intel NIC, needed in the initrd for SSH unlock.
  boot.initrd.availableKernelModules = [ "e1000e" ];

  time.timeZone = "America/New_York";
}
