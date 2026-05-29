{
  # Local DNS zone served by janus.
  domain = "lan";

  vlans = import ./vlans.nix;
  hosts = import ./hosts.nix;
}
