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
    self.users.fmzakari.nixosModule

    base
    latest-kernel
    nvim-dev
    zsh
    llm-tools
    auto-timezone
    auto-pressure-gc
    btrfs
    smartd
    desktop
    librewolf
    plymouth
    keyring-tpm
    niri
    noctalia
    niri-autologin
    keyboard
    zram
    laptop
    printing
    chat-apps
    gaming
    creative-apps
    yubikey
    ssh-tpm-agent
    mullvad
    virt-manager
    rbw
    command-lookup
    tailscale-travel
  ];

  system.primaryUser = self.users.alex.username;

  gitSigning.key = "modus-tpm";

  tailscaleTravel.defaultExitNode = "sequoia";

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
