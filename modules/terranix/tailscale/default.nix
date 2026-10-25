# Tailscale provider, the tailnet policy file, split DNS and janus's routes
{
  imports = [
    ./provider.nix
    ./acl.nix
    ./dns.nix
  ];
}
