{
  assignments = import ./assignments.nix;
  hosts = import ./hosts.nix;
  networks = import ./networks.nix;
  plans = import ./plans.nix;
  tenants = import ./tenants;
}
