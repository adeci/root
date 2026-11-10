{
  inputs,
  pkgs,
  self,
  ...
}:
{
  imports = with self.modules.nixos; [
    inputs.nixos-hardware.nixosModules.gpd-pocket-4

    self.users.alex.nixosModule

    ./modules/gpd-hacks.nix
    ./modules/gpd-audio-dsp.nix
    ./modules/viture-beast-audio.nix
    base
    nvim-dev
    emacs
    zsh
    atuin-login
    llm-tools
    auto-timezone
    auto-pressure-gc
    smartd
    desktop
    niri
    noctalia
    niri-autologin
    keyd
    amd-gpu
    zram
    laptop
    printing
    social
    gaming
    creative
    yubikey
    ssh-tpm-agent
    mullvad
    rbw
    cheat
    tailscale-travel
    remote-hosts
  ];

  thaw.apps.niri.files."machine.kdl" = ./niri.kdl;

  # gsim module
  networking.modemmanager.enable = true;

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    kernelParams = [
      "pcie_ports=native"
    ];
  };

  environment.systemPackages = [
    # pkgs.bitwarden-desktop # Electron 39 is EOL; re-enable once nixpkgs updates it
    pkgs.mullvad-browser
    pkgs.calibre
    pkgs.modem-manager-gui
    pkgs.linux-wifi-hotspot
    self.packages.${pkgs.stdenv.hostPlatform.system}.sdwire-cli
    pkgs.ethtool
    pkgs.displaycal
    pkgs.android-tools
    inputs.mandate.packages.${pkgs.stdenv.hostPlatform.system}.mandate
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
