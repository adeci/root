{
  inputs,
  config,
  lib,
  self,
  ...
}:
{
  imports = [
    inputs.clan-core.nixosModules.installer
  ];

  clan.core.settings.state-version.enable = false;
  system.stateVersion = config.system.nixos.release;

  nixpkgs.hostPlatform = "x86_64-linux";
  users.users.root.initialHashedPassword = lib.mkForce null;

  # Keymap and locale
  console.keyMap = "us";
  services.xserver.xkb.layout = "us";
  i18n.defaultLocale = "en_US.UTF-8";

  # SSH key baked in so no need for --ssh-pubkey at flash time
  users.users.root.openssh.authorizedKeys.keys = self.users.alex.sshKeys;

  # Boot
  boot.loader.grub.enable = lib.mkDefault true;
  boot.loader.grub.efiSupport = lib.mkDefault true;
  boot.loader.grub.efiInstallAsRemovable = lib.mkDefault true;
}
