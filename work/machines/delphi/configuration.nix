{
  pkgs,
  self,
  workInputs,
  ...
}:
{
  imports = [
    workInputs.nixos-hardware-xps14.nixosModules.dell-xps-14-da14260

    self.users.alex-work.nixosModule

    ../../modules/nixos/apps.nix
    ../../modules/nixos/enrollment.nix
    ../../modules/nixos/shell.nix
    ../../modules/nixos/zsh.nix

    (self + "/modules/nixos/base.nix")
    (self + "/modules/nixos/nvim-dev.nix")
    (self + "/modules/nixos/llm-config.nix")
    (self + "/modules/nixos/auto-timezone.nix")
    (self + "/modules/nixos/auto-pressure-gc.nix")
    (self + "/modules/nixos/btrfs.nix")
    (self + "/modules/nixos/smartd.nix")
    (self + "/modules/nixos/desktop")
    (self + "/modules/nixos/desktop/unlock.nix")
    (self + "/modules/nixos/desktop/keyring-tpm")
    (self + "/modules/nixos/niri")
    (self + "/modules/nixos/noctalia.nix")
    (self + "/modules/nixos/niri/autologin.nix")
    (self + "/modules/nixos/keyd.nix")
    (self + "/modules/nixos/zram.nix")
    (self + "/modules/nixos/laptop.nix")
    (self + "/modules/nixos/printing.nix")
    (self + "/modules/nixos/yubikey.nix")
    (self + "/modules/nixos/ssh-tpm-agent.nix")
  ];

  thaw.apps.niri.files."machine.kdl" = ./niri.kdl;

  nixpkgs.hostPlatform = "x86_64-linux";

  # Newest series confirmed on the DA14260.
  boot.kernelPackages = pkgs.linuxPackages_7_2;
}
