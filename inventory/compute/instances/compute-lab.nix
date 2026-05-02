{
  id = 10;
  network = "tenant";
  hypervisor = "cloud-hypervisor";
  # Preserve the live DHCP reservation while microcompute's default MAC
  # generation uses hexadecimal octets for new instances. This reserves the
  # auto-generated MAC for id = 16 on this network.
  mac = "02:00:00:40:00:10";

  resources = {
    vcpu = 2;
    memoryMiB = 3072;
  };

  lifecycle = {
    autostart = false;
    restartIfChanged = false;
  };

  bootstrap = {
    transport = "seed-disk";
    material = "age-key-file";
  };

  volumes = [
    {
      name = "state";
      mountPoint = "/var/lib/tenant";
      sizeMiB = 8192;
    }
  ];
}
