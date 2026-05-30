{
  # Local DNS zone served by janus.
  domain = "lan";

  vlans = import ./vlans.nix;
  hosts = import ./hosts.nix;
  dns = import ./dns.nix;
}
