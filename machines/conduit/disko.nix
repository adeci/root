{
  disko.devices.disk.main = {
    name = "main-68f896d62dfe4d11928de8b0a1ee134c";
    device = "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_114557658";
    content.partitions.swap = {
      size = "4G";
      content = {
        type = "swap";
        discardPolicy = "both";
      };
    };
  };
}
