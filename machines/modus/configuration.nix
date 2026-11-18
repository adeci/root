{
  inputs,
  pkgs,
  self,
  ...
}:
{
  imports = with self.modules.nixos; [
    inputs.nixos-hardware.nixosModules.framework-intel-core-ultra-series3

    self.users.alex.nixosModule

    workstation
    llm-tools
    chat-apps
    mullvad
    latest-kernel
    emacs
    btrfs
    keyring-tpm
    gaming
    creative-apps
    ssh-tpm-agent
    virt-manager
    tailscale-travel
  ];

  gitSigning.key = "modus-tpm";

  tailscaleTravel.defaultExitNode = "sequoia";

  # The firmware write-protects the memory's SPD chip, so spd5118 fails to restore itself on every resume.
  boot.blacklistedKernelModules = [ "spd5118" ];

  wrappers.niri.machineConfig = # kdl
    ''
      output "eDP-1" {
          mode "2880x1920@120"
          scale 2
          position x=560 y=1440
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
    '';

  environment.systemPackages = [
    pkgs.calibre
    pkgs.ethtool
    pkgs.android-tools
  ];
}
