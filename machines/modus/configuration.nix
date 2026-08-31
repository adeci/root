{
  inputs,
  pkgs,
  self,
  ...
}:
{
  imports = [
    inputs.nixos-hardware.nixosModules.framework-intel-core-ultra-series3

    self.users.alex.nixosModule

    ../../modules/nixos/base.nix
    ../../modules/nixos/zsh.nix
    ../../modules/nixos/llm-tools.nix
    ../../modules/nixos/auto-timezone.nix
    ../../modules/nixos/auto-pressure-gc.nix
    ../../modules/nixos/btrfs.nix
    ../../modules/nixos/smartd.nix
    ../../modules/nixos/desktop.nix
    ../../modules/nixos/niri-autologin.nix
    ../../modules/nixos/keyd.nix
    ../../modules/nixos/zram.nix
    ../../modules/nixos/laptop.nix
    ../../modules/nixos/printing.nix
    ../../modules/nixos/social.nix
    ../../modules/nixos/gaming.nix
    ../../modules/nixos/creative.nix
    ../../modules/nixos/yubikey.nix
    ../../modules/nixos/voxtype.nix
    ../../modules/nixos/ssh-tpm-agent.nix
    ../../modules/nixos/mullvad.nix
    ../../modules/nixos/rbw.nix
    ../../modules/nixos/cheat.nix
    ../../modules/nixos/tailscale-travel.nix
    ../../modules/nixos/remote-hosts.nix
  ];

  environment.systemPackages = [
    (self.wrappers.noctalia-shell.wrap {
      inherit pkgs;
      settings.systemMonitor.enableDgpuMonitoring = true;
    })
    pkgs.mullvad-browser
    pkgs.calibre
    pkgs.ethtool
    pkgs.android-tools
  ];

  # vm building
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;

  nix.settings.trusted-users = [
    "root"
    self.users.alex.username
  ];
}
