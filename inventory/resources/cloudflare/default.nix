{
  zones = import ./zones.nix;
  tunnels = import ./tunnels.nix;
  dns = import ./dns.nix;
  firewall = import ./firewall.nix;
  redirects = import ./redirects.nix;
}
