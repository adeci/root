{
  # Keep Leviathan responsive under CI/build pressure. Current tmux-managed game
  # servers are intentionally unchanged; MicroVMs are isolated under compute.slice.

  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 262144; # 256 GiB
      priority = 10;
    }
  ];

  boot.kernel.sysctl = {
    "vm.swappiness" = 60;
    "vm.page-cluster" = 0;
  };

  systemd.slices.ci = {
    description = "Best-effort CI and Nix build workloads";
    sliceConfig = {
      MemoryAccounting = true;
      IOAccounting = true;
      CPUWeight = 100;
      IOWeight = 100;
      MemoryHigh = "96G";
      MemoryMax = "128G";
    };
  };

  systemd.slices.compute.sliceConfig = {
    MemoryLow = "16G";
    MemoryMax = "96G";
  };

  systemd.services.nix-daemon.serviceConfig = {
    Slice = "ci.slice";
    OOMScoreAdjust = 500;
  };

  systemd.services.buildbot-master.serviceConfig = {
    Slice = "ci.slice";
    OOMScoreAdjust = 500;
  };

  systemd.services.buildbot-worker.serviceConfig = {
    Slice = "ci.slice";
    OOMScoreAdjust = 500;
  };
}
