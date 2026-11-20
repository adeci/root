# Agent machines as { os, kind, backsUp }, backsUp if the inventory backs it up.
machines: {
  fleet = import ./fleet.nix machines;
  backups = import ./backups.nix machines;
}
