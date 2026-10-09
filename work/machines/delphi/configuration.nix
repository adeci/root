{
  pkgs,
  self,
  workInputs,
  workUsers,
  ...
}:
{
  imports = [
    workInputs.nixos-hardware.nixosModules.dell-xps-14-da14260

    workUsers.alex.nixosModule

    ../../modules/nixos/shopify.nix

    (self + "/modules/nixos/base.nix")
    (self + "/modules/nixos/zsh.nix")
    (self + "/modules/nixos/llm-tools.nix")
    (self + "/modules/nixos/auto-timezone.nix")
    (self + "/modules/nixos/auto-pressure-gc.nix")
    (self + "/modules/nixos/btrfs.nix")
    (self + "/modules/nixos/smartd.nix")
    (self + "/modules/nixos/desktop.nix")
    (self + "/modules/nixos/noctalia-shell.nix")
    (self + "/modules/nixos/niri-autologin.nix")
    (self + "/modules/nixos/keyd.nix")
    (self + "/modules/nixos/zram.nix")
    (self + "/modules/nixos/laptop.nix")
    (self + "/modules/nixos/printing.nix")
    (self + "/modules/nixos/yubikey.nix")
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

  # Newest kernel confirmed on the DA14260 with this profile. The pinned
  # nixpkgs only has 7.2.0; drop this with the next nixpkgs update.
  boot.kernelPackages = pkgs.linuxPackagesFor (
    pkgs.linux_7_2.override {
      argsOverride = rec {
        version = "7.2.8";
        modDirVersion = version;
        src = pkgs.fetchurl {
          url = "mirror://kernel/linux/kernel/v7.x/linux-${version}.tar.xz";
          hash = "sha256-EujVqXPRrXxaXGmILkAisTHtcV23AD/c12Dd+MPlGUE=";
        };
      };
    }
  );
}
