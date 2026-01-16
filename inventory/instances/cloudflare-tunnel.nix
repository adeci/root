{
  "sequoia-tunnels" = {
    module = {
      name = "@onix/cloudflare-tunnel";
      input = "self";
    };
    roles.default = {
      machines.sequoia = {
        settings = {
          tokenName = "adeci";
          tunnelName = "sequoia-services";
          ingress = {
            "vault.decio.us" = "http://localhost:8222";
            "adeci.dev" = "http://localhost:3000";
          };
        };
      };
    };
  };

  "praxis-tunnels" = {
    module = {
      name = "@onix/cloudflare-tunnel";
      input = "self";
    };
    roles.default = {
      machines.praxis = {
        settings = {
          tokenName = "adeci";
          tunnelName = "praxis-services";
          ingress = {
            "vault2.decio.us" = "http://localhost:8222";
          };
        };
      };
    };
  };
}
