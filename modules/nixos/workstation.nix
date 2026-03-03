_: {
  boot.kernel.sysctl = {
    "vm.swappiness" = 60;
    "vm.dirty_ratio" = 15;
    "vm.dirty_background_ratio" = 5;
    "vm.overcommit_memory" = 1;
    "vm.page-cluster" = 0;
  };
  zramSwap = {
    enable = true;
    algorithm = "lz4";
    memoryPercent = 87;
    priority = 100;
  };
}
