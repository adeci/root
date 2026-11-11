{
  zones = import ./zones.nix;
  tunnels = import ./tunnels.nix;
  # Clan var that terraform sets to each tunnel's token on the tunnel's machine.
  tunnelToken = {
    generator = "cloudflare-tunnel-token";
    file = "token";
  };
  # Shared clan var with the DNS API token for ACME challenges; prompted, not set by terraform.
  acmeTokenGenerator = "cloudflare-acme-decio-us";
  dns = import ./dns.nix;
  firewall = import ./firewall.nix;
  redirects = import ./redirects.nix;
}
