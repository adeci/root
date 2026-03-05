_: {
  nix.settings = {
    extra-substituters = [ "https://cache.numtide.com?priority=42" ];
    extra-trusted-public-keys = [
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];
  };
}
