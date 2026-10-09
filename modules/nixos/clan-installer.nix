{
  inputs,
  config,
  lib,
  ...
}:
{
  imports = [ inputs.clan-core.nixosModules.installer ];

  clan.core.settings.state-version.enable = false;
  system.stateVersion = config.system.nixos.release;
  users.users.root.initialHashedPassword = lib.mkForce null;

  console.keyMap = "us";
  services.xserver.xkb.layout = "us";
  i18n.defaultLocale = "en_US.UTF-8";

  boot.loader.grub.enable = lib.mkDefault true;
  boot.loader.grub.efiSupport = lib.mkDefault true;
  boot.loader.grub.efiInstallAsRemovable = lib.mkDefault true;

  # USB stick partition layout (from clan-core's flash-installer)
  disko.devices.disk.main = {
    type = "disk";
    device = lib.mkDefault "/dev/null";
    content = {
      type = "gpt";
      partitions = {
        boot = {
          size = "1M";
          type = "EF02"; # for grub MBR
          priority = 1;
        };
        ESP = {
          size = "512M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
          };
        };
        root = {
          name = "root";
          end = "-0";
          content = {
            type = "filesystem";
            format = "f2fs";
            mountpoint = "/";
            extraArgs = [
              "-O"
              "extra_attr,inode_checksum,sb_checksum,compression"
            ];
            # Recommendations for flash: https://wiki.archlinux.org/title/F2FS#Recommended_mount_options
            mountOptions = [
              "compress_algorithm=zstd:6,compress_chksum,atgc,gc_merge,lazytime,nodiscard"
            ];
          };
        };
      };
    };
  };
}
