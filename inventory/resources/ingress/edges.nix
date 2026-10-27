{
  conduit = {
    provider = "hcloud";
    firewall = {
      # SSH is Tailscale-only (see modules/nixos/public-edge.nix). For Hetzner
      # rescue, temporarily add tcp/22 here and apply.
      staticRules = [
        {
          description = "HTTP (Zipline)";
          protocol = "tcp";
          port = 80;
        }
        {
          description = "HTTPS (Zipline)";
          protocol = "tcp";
          port = 443;
        }
        {
          description = "Tailscale direct WireGuard endpoint";
          protocol = "udp";
          port = 41641;
        }
      ];
    };
  };
}
