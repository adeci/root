{
  id = 10;
  network = "tenant";
  plan = "small";
  lifecycle = {
    autostart = false;
    restartIfChanged = false;
  };

  bootstrap.method = "seed-age-key";

  volumes = [
    {
      name = "state";
      mountPoint = "/var/lib/tenant";
      sizeMiB = 8192;
    }
  ];
}
