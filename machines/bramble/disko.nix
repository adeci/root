# The Pi firmware reads the first FAT partition, which also holds U-Boot's
# extlinux generations.
{
  disko.devices = {
    disk.main = {
      device = "/dev/disk/by-id/mmc-USD00_0x31605b53";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          firmware = {
            priority = 1;
            size = "512M";
            type = "0700";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };

          swap = {
            size = "16G";
            content.type = "swap";
          };

          root = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
            };
          };
        };
      };
    };
  };
}
