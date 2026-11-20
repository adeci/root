# The pages get the agent machines, each as { os, kind, backsUp }, backsUp being whether the inventory backs it up.
machines: {
  fleet = import ./fleet.nix machines;
  backups = import ./backups.nix machines;
}
