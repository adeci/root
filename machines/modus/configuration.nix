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
    nvim-dev
    zsh
    llm-tools
    auto-timezone
    auto-pressure-gc
    btrfs
    smartd
    desktop
    librewolf
    desktop-unlock
    keyring-tpm
    niri
    noctalia
    niri-autologin
    keyd
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

  system.primaryUser = self.users.alex.username;

  gitSigning.key = "modus-tpm";

  tailscaleTravel.defaultExitNode = "sequoia";

  wrappers.niri.machineConfig = # kdl
    ''
      output "BOE NE135A1M-NY1 Unknown" {
          mode "2880x1920@120"
          scale 2
          transform "normal"
          position x=560 y=1440
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
    '';

  environment.systemPackages = [
    pkgs.mullvad-browser
    pkgs.calibre
    pkgs.ethtool
    pkgs.android-tools
  ];

  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;

  nix.settings.trusted-users = [
    "root"
    self.users.alex.username
  ];
}
