{
  inputs,
  pkgs,
  config,
  ...
}:

{

  imports = [
    inputs.nixos-hardware.nixosModules.gpd-pocket-4

    ../../modules/nixos/home-manager.nix

    ../../modules/nixos/base.nix
    ../../modules/nixos/auto-timezone.nix
    ../../modules/nixos/dev.nix
    ../../modules/nixos/niri.nix
    ../../modules/nixos/keyd.nix
    ../../modules/nixos/amd-gpu.nix
    ../../modules/nixos/zram.nix
    ../../modules/nixos/laptop.nix
    ../../modules/nixos/gpd-pocket-4-hacks
    ../../modules/nixos/printing.nix
    ../../modules/nixos/social.nix
    ../../modules/nixos/gaming.nix
    ../../modules/nixos/creative.nix
    ../../modules/nixos/llm-secrets.nix
    ../../modules/nixos/remote-builder.nix
  ];

  home-manager.users.alex = import ./home.nix;

  boot.kernelPackages = pkgs.linuxPackagesFor (
    pkgs.linux_6_19.override {
      argsOverride = rec {
        version = "6.19.6";
        modDirVersion = "6.19.6";
        src = pkgs.fetchurl {
          url = "mirror://kernel/linux/kernel/v6.x/linux-${version}.tar.xz";
          hash = "sha256-TZ8/9zIU9owBlO8C25ykt7pxMlOsEEVEHU6fNSvCLhQ=";
        };
      };
    }
  );
  boot.extraModulePackages = [ config.boot.kernelPackages.acpi_call ];

  environment.systemPackages = with pkgs; [
    # calibre
    modem-manager-gui
    linux-wifi-hotspot
    inputs.sdwire-cli.packages.${pkgs.stdenv.hostPlatform.system}.default
    amd-debug-tools
    ethtool
  ];

  networking = {
    networkmanager.enable = true;
    modemmanager.enable = true;
    hostName = "praxis";
  };

  # vm building
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;

  nix.settings.trusted-users = [
    "root"
    config.adeci.primaryUser
  ];

  services.udev.extraRules = ''
    # SDWire USB SD card mux (usb device + block device for dd without sudo)
    SUBSYSTEM=="usb", ATTRS{idVendor}=="0bda", ATTRS{idProduct}=="0316", MODE="0666"
    SUBSYSTEM=="block", ATTRS{idVendor}=="0bda", ATTRS{idProduct}=="0316", MODE="0666"

    # RP2350/RP2040 BOOTSEL mode
    SUBSYSTEM=="usb", ATTRS{idVendor}=="2e8a", MODE="0666"
    SUBSYSTEM=="block", ATTRS{idVendor}=="2e8a", MODE="0666"
  '';

}
