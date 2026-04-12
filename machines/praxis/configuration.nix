{
  inputs,
  pkgs,
  config,
  self,
  ...
}:

{

  imports = [
    inputs.nixos-hardware.nixosModules.gpd-pocket-4

    self.users.alex.nixosModule

    ./modules/gpd-hacks.nix
    ./modules/gpd-audio-dsp.nix

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
    ../../modules/nixos/yubikey.nix
    ../../modules/nixos/ssh-tpm-agent.nix
    ../../modules/nixos/mullvad.nix
    ../../modules/nixos/rbw.nix
    ../../modules/nixos/cheat.nix
  ];

  # gsim module
  networking.modemmanager.enable = true;

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

  services.teamviewer.enable = true;

  environment.systemPackages = [
    pkgs.bitwarden-desktop
    pkgs.mullvad-browser
    pkgs.calibre
    pkgs.modem-manager-gui
    pkgs.linux-wifi-hotspot
    inputs.sdwire-cli.packages.${pkgs.stdenv.hostPlatform.system}.default
    pkgs.amd-debug-tools
    pkgs.ethtool
  ];

  # vm building
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;

  services.udev.extraRules = ''
    # SDWire USB SD card mux (usb device + block device for dd without sudo)
    SUBSYSTEM=="usb", ATTRS{idVendor}=="0bda", ATTRS{idProduct}=="0316", MODE="0666"
    SUBSYSTEM=="block", ATTRS{idVendor}=="0bda", ATTRS{idProduct}=="0316", MODE="0666"

    # RP2350/RP2040 BOOTSEL mode
    SUBSYSTEM=="usb", ATTRS{idVendor}=="2e8a", MODE="0666"
    SUBSYSTEM=="block", ATTRS{idVendor}=="2e8a", MODE="0666"
  '';

  nix.settings.trusted-users = [
    "root"
    self.users.alex.username
  ];
}
