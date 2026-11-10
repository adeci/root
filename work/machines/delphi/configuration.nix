{
  pkgs,
  self,
  workInputs,
  ...
}:
{
  imports = with self.modules.nixos; [
    workInputs.nixos-hardware-xps14.nixosModules.dell-xps-14-da14260

    self.users.alex-work.nixosModule

    workInputs.self.modules.nixos.apps
    workInputs.self.modules.nixos.enrollment
    workInputs.self.modules.nixos.shell
    workInputs.self.modules.nixos.zsh

    base
    nvim-dev
    llm-config
    auto-timezone
    auto-pressure-gc
    btrfs
    smartd
    desktop
    desktop-unlock
    keyring-tpm
    niri
    noctalia
    niri-autologin
    keyd
    zram
    laptop
    printing
    yubikey
    ssh-tpm-agent
  ];

  thaw.apps.niri.files."machine.kdl" = ./niri.kdl;

  nixpkgs.hostPlatform = "x86_64-linux";

  # Newest series confirmed on the DA14260.
  boot.kernelPackages = pkgs.linuxPackages_7_2;
}
