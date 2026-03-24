{
  inputs,
  config,
  lib,
  ...
}:
{
  imports = [
    inputs.clan-core.nixosModules.installer
  ];

  # Live installer — no state-version tracking needed
  clan.core.settings.state-version.enable = false;
  system.stateVersion = config.system.nixos.release;

  nixpkgs.hostPlatform = "x86_64-linux";
  users.users.root.initialHashedPassword = lib.mkForce null;

  # Keymap and locale
  console.keyMap = "us";
  services.xserver.xkb.layout = "us";
  i18n.defaultLocale = "en_US.UTF-8";

  # SSH access — baked in so we don't need --ssh-pubkey at flash time
  users.users.root.openssh.authorizedKeys.keys =
    (import ../../inventory/instances/roster/users.nix).alex.sshAuthorizedKeys;

  # Boot
  boot.loader.grub.enable = lib.mkDefault true;
  boot.loader.grub.efiSupport = lib.mkDefault true;
  boot.loader.grub.efiInstallAsRemovable = lib.mkDefault true;
}
