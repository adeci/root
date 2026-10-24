{
  inputs,
  pkgs,
  self,
  ...
}:
{
  imports = [
    inputs.nixos-hardware-xps14.nixosModules.dell-xps-14-da14260

    self.users.alex-work.nixosModule

    ../../modules/nixos/work/apps.nix
    ../../modules/nixos/work/enrollment.nix
    ../../modules/nixos/work/shell.nix
    ../../modules/nixos/work/zsh.nix

    ../../modules/nixos/base.nix
    ../../modules/nixos/llm-config.nix
    ../../modules/nixos/auto-timezone.nix
    ../../modules/nixos/auto-pressure-gc.nix
    ../../modules/nixos/btrfs.nix
    ../../modules/nixos/smartd.nix
    ../../modules/nixos/desktop
    ../../modules/nixos/desktop/unlock.nix
    ../../modules/nixos/niri
    ../../modules/nixos/noctalia.nix
    ../../modules/nixos/niri/autologin.nix
    ../../modules/nixos/keyd.nix
    ../../modules/nixos/zram.nix
    ../../modules/nixos/laptop.nix
    ../../modules/nixos/printing.nix
    ../../modules/nixos/yubikey.nix
    ../../modules/nixos/ssh-tpm-agent.nix
  ];

  thaw.apps.niri.files."machine.kdl" = ./niri.kdl;

  nixpkgs.hostPlatform = "x86_64-linux";

  # Newest series confirmed on the DA14260.
  boot.kernelPackages = pkgs.linuxPackages_7_2.extend (
    _: prev: {
      # Depmod collision; drop once nixos-unstable has nixpkgs#575861.
      v4l2loopback = prev.v4l2loopback.overrideAttrs (old: {
        installFlags = (old.installFlags or [ ]) ++ [ "DEPMOD=true" ];
      });
    }
  );
}
