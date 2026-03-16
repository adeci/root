# ---
# schema = "ext4-single-disk"
# [placeholders]
# mainDisk = "/dev/disk/by-id/ata-TEAM_T2531TB_TPBF2503250060305898" 
# ---
# This file was automatically generated!
# CHANGING this configuration requires wiping and reinstalling the machine
{
  boot.loader.grub = {
    efiInstallAsRemovable = true;
    efiSupport = true;
  };

  disko.devices = {
    disk = {
      main = {
        name = "main-36978c68ef5c4d95a13359fc9b48c597";
        device = "/dev/disk/by-id/ata-TEAM_T2531TB_TPBF2503250060305898";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            "boot" = {
              size = "1M";
              type = "EF02"; # for grub MBR
              priority = 1;
            };
            ESP = {
              type = "EF00";
              size = "500M";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
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
