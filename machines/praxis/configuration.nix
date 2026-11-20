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

    workstation
    llm-tools
    chat-apps
    mullvad
    latest-kernel
    emacs
    amd-gpu
    gaming
    creative-apps
    ssh-tpm-agent
    virt-manager
    tailscale-travel
    sdwire

    ./modules/gpd-hacks
    ./modules/gpd-audio-dsp.nix
    ./modules/viture-beast-audio.nix
  ];

  gitSigning.key = "praxis-tpm";

  tailscaleTravel.defaultExitNode = "sequoia";

  # Restic instance and its excludes: inventory/clan-instances.nix.
  clan.core.state.home.folders = [ "/home/alex" ];

  wrappers.btop.settings.cpu_sensor = "k10temp/Tctl";

  wrappers.niri.machineConfig = # kdl
    ''
      output "PNP(HSX) YHB03P24 0x00888888" {
          mode "1600x2560@143.999"
          scale 2
          position x=640 y=1440
      }

      output "Microstep MSI MD272QPW PB1H252600064" {
          mode "2560x1440@59.951"
          scale 1
          position x=0 y=0
      }

      output "Microstep MSI MAG321CQR KA3H071804955" {
          mode "2560x1440@144"
          scale 1
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

  boot.kernelParams = [ "pcie_ports=native" ];

  environment.systemPackages = [
    pkgs.calibre
    pkgs.modem-manager-gui
    pkgs.linux-wifi-hotspot
    pkgs.ethtool
    pkgs.displaycal
    pkgs.android-tools
    inputs.mandate.packages.${pkgs.stdenv.hostPlatform.system}.mandate
  ];

  # RP2350/RP2040 in BOOTSEL for the seat user; 70 for the reason in the sdwire module.
  services.udev.packages = [
    (pkgs.writeTextDir "lib/udev/rules.d/70-rp2040.rules" ''
      SUBSYSTEM=="usb", ATTRS{idVendor}=="2e8a", TAG+="uaccess"
      SUBSYSTEM=="block", ATTRS{idVendor}=="2e8a", TAG+="uaccess"
    '')
  ];
}
