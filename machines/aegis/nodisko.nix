# schema = "single-disk"
# mainDisk = "/dev/disk/by-id/ata-HITACHI_HTS543232A7A384_E2034233HAARAS"
{

  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    efiInstallAsRemovable = true;
    device = "nodev";
  };
  disko.devices = {
    disk = {
      main = {
        name = "main-a6cf875494b64d81ab66f38c06532c69";
        device = "/dev/disk/by-id/ata-HITACHI_HTS543232A7A384_E2034233HAARAS";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              type = "EF00";
              size = "1G";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            swap = {
              name = "swap";
              size = "8G";
              content = {
                type = "swap";
              };
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
  };
}
