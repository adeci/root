{
  assignments = import ./assignments.nix;
  hosts = import ./hosts.nix;
  networks = import ./networks.nix;
  instances = import ./instances;
}
