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
    atuin-login
    llm-tools
    auto-timezone
    auto-pressure-gc
    btrfs
    smartd
    desktop
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
    remote-hosts
  ];

  thaw.apps.niri.files."machine.kdl" = ./niri.kdl;

  environment.systemPackages = [
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
