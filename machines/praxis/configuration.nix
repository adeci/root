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
    ../../modules/nixos/ssh.nix
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

  # Pin to 6.18.12 — s2idle regression between 6.18.13–6.18.15 breaks
  # hardware sleep on this machine. Remove once the regression is identified.
  boot.kernelPackages = pkgs.linuxPackagesFor (
    pkgs.linux_6_18.override {
      argsOverride = rec {
        version = "6.18.12";
        modDirVersion = version;
        src = pkgs.fetchurl {
          url = "mirror://kernel/linux/kernel/v6.x/linux-${version}.tar.xz";
          hash = "sha256-4AMpStTCwqxbt3+7gllRETT1HZh7MhJRaDLcSwyD8eo=";
        };
      };
    }
  );

  environment.systemPackages = with pkgs; [
    # calibre # broken in nixpkgs — qmake missing from qt6 setup hook
    # modem-manager-gui
    linux-wifi-hotspot
    inputs.sdwire-cli.packages.${pkgs.stdenv.hostPlatform.system}.default
    amd-debug-tools
    ethtool
  ];

  networking = {
    networkmanager.enable = true;
    hostName = "praxis";
  };

  # systemd.services.ModemManager = {
  #   wantedBy = [ "multi-user.target" ];
  # };

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
