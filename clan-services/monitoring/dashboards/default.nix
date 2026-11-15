# The fleet page gets the agent machines, each as { os, kind }.
machines: {
  fleet = import ./fleet.nix machines;
}
