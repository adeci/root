{
  boot.loader.grub = {
    efiInstallAsRemovable = true;
    efiSupport = true;
  };

  disko.devices.disk.main = {
    name = "main-68f896d62dfe4d11928de8b0a1ee134c";
    device = "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_114557658";
    type = "disk";

    content = {
      type = "gpt";

      partitions = {
        boot = {
          size = "1M";
          type = "EF02";
          priority = 1;
        };

        ESP = {
          size = "500M";
          type = "EF00";
          priority = 2;

          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };

        swap = {
          size = "4G";
          priority = 3;

          content = {
            type = "swap";
            discardPolicy = "both";
          };
        };

        root = {
          size = "100%";
          priority = 4;

          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
}
