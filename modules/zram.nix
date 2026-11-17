{
  nixos = {
    boot.kernel.sysctl = {
      "vm.dirty_ratio" = 15;
      "vm.dirty_background_ratio" = 5;
      "vm.overcommit_memory" = 1;
      "vm.page-cluster" = 0;
    };
    zramSwap = {
      enable = true;
      priority = 100;
    };
  };
}
