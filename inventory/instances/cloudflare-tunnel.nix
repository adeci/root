{

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
            "adeci.dev" = "http://localhost:4444";
            "trader.decio.us" = "http://localhost:5555";
          };
        };
      };
    };
  };

}
