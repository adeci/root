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
          description = "Pressroom HTTP";
          protocol = "tcp";
          port = 80;
        }
        {
          description = "Pressroom HTTPS";
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
