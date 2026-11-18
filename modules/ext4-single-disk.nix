{
  # The machine sets disko.devices.disk.main's device and its name (the installed partition labels derive from it), and declares its swap partition.
  nixos = {
    boot.loader.grub = {
      efiSupport = true;
      efiInstallAsRemovable = true;
    };

    disko.devices.disk.main = {
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          boot = {
            size = "1M";
            type = "EF02"; # for grub MBR
            priority = 1;
          };
          ESP = {
            size = "500M";
            type = "EF00";
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
}
