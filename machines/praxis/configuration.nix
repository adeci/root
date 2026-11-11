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
    librewolf
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
  ];

  tailscaleTravel.defaultExitNode = "sequoia";

  wrappers.btop.settings.cpu_sensor = "k10temp/Tctl";

  wrappers.niri.machineConfig = # kdl
    ''
      output "PNP(HSX) YHB03P24 0x00888888" {
          mode "1600x2560@143.999"
          scale 2
          transform "normal"
          position x=640 y=1440
      }

      output "Microstep MSI MD272QPW PB1H252600064" {
          mode "2560x1440@59.951"
          scale 1
          transform "normal"
          position x=0 y=0
      }

      output "Microstep MSI MAG321CQR KA3H071804955" {
          mode "2560x1440@144"
          scale 1
          transform "normal"
          position x=0 y=0
          layout {
              default-column-width {
                  proportion 0.33333
              }
              preset-column-widths {
                  proportion 0.25
                  proportion 0.33333
                  proportion 0.5
                  proportion 0.66667
              }
          }
      }

      input {
          touch {
              map-to-output "eDP-1"
          }
      }

      binds {
          Mod+Alt+R hotkey-overlay-title="Rotate display upside down" { spawn "niri" "msg" "output" "eDP-1" "transform" "180"; }
      }
    '';

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
