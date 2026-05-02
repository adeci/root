{
  id = 10;
  network = "tenant";
  hypervisor = "cloud-hypervisor";

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
