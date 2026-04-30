{
  id = 10;
  network = "tenant";
  plan = "small";
  tags = [ "tenant-vm" ];

  lifecycle = {
    autostart = false;
    restartIfChanged = false;
  };

  volumes = [
    {
      name = "state";
      mountPoint = "/var/lib/tenant";
      sizeMiB = 8192;
    }
  ];
}
