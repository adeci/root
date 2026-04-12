{
  inputs,
  pkgs,
  self,
  ...
}:

let

  grubWallpaper = pkgs.fetchurl {
    name = "nixos-grub-wallpaper.jpg";
    url = "https://raw.githubusercontent.com/adeci/wallpapers/main/nix-grub-2880x1920.jpg";
    sha256 = "sha256-Xu3KlpNMiZzS2fXYGGx0u0Qch7CoEus6ODwNVL4Bq4U=";
  };

in
{

  imports = [
    self.users.alex.nixosModule

    inputs.nixos-hardware.nixosModules.framework-13-7040-amd
    inputs.grub2-themes.nixosModules.default

    ../../modules/nixos/base.nix
    ../../modules/nixos/zsh.nix
    ../../modules/nixos/llm-tools.nix
    ../../modules/nixos/auto-timezone.nix
    ../../modules/nixos/desktop.nix
    ../../modules/nixos/niri-autologin.nix
    ../../modules/nixos/keyd.nix
    ../../modules/nixos/amd-gpu.nix
    ../../modules/nixos/zram.nix
    ../../modules/nixos/laptop.nix
    ../../modules/nixos/printing.nix
    ../../modules/nixos/social.nix
    ../../modules/nixos/gaming.nix
    ../../modules/nixos/creative.nix
  ];

  environment.systemPackages = [
    pkgs.imagemagick
    pkgs.os-prober
    # pkgs.calibre # broken in nixpkgs — qmake missing from qt6 setup hook
    pkgs.linux-wifi-hotspot
  ];

  # vm building
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;

  boot.loader = {
    timeout = 1;
    grub = {
      timeoutStyle = "menu";
      useOSProber = true;
    };
    grub2-theme = {
      enable = true;
      theme = "stylish";
      footer = true;
      customResolution = "2880x1920";
      splashImage = grubWallpaper;
    };
  };

  nix.settings.trusted-users = [
    "root"
    self.users.alex.username
  ];

}
