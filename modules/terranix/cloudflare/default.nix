# Cloudflare provider + zone data sources
# Tunnels in tunnels.nix, DNS records in dns.nix.
{
  imports = [
    ./provider.nix
    ./tunnels.nix
    ./dns.nix
  ];
}
