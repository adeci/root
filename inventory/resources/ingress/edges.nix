{
  conduit = {
    provider = "hcloud";
    firewall = {
      staticRules = [
        {
          description = "SSH";
          protocol = "tcp";
          port = 22;
        }
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
