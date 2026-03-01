{
  inputs,
  pkgs,
  config,
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

    inputs.nixos-hardware.nixosModules.framework-13-7040-amd

    inputs.grub2-themes.nixosModules.default

    ../../modules/nixos
  ];

  adeci = {
    base.enable = true;
    dev.enable = true;
    shell.enable = true;
    niri.enable = true;
    keyd.enable = true;
    amd-gpu.enable = true;
    ssh.enable = true;
    workstation.enable = true;
    laptop.enable = true;
    printing.enable = true;
    social.enable = true;
    gaming.enable = true;
    creative.enable = true;
  };

  environment.systemPackages = with pkgs; [
    imagemagick
    os-prober
    calibre
    linux-wifi-hotspot
  ];

  networking = {
    networkmanager.enable = true;
    hostName = "modus";
  };

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
    config.adeci.primaryUser
  ];

}
