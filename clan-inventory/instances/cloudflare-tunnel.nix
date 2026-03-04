{

  "sequoia-tunnels" = {
    module = {
      name = "@adeci/cloudflare-tunnel";
      input = "self";
    };
    roles.default = {
      machines.sequoia = {
        settings = {
          tokenName = "adeci";
          tunnelName = "sequoia-services";
          ingress = {
            "vault.decio.us" = "http://localhost:8222";
            "adeci.dev" = "http://localhost:4444";
            "trader.decio.us" = "http://localhost:5555";
            "matrix.decio.us" = "http://localhost:8448";
            "decio.us" = "http://localhost:8748";
          };
        };
      };
    };
  };

  "leviathan-tunnels" = {
    module = {
      name = "@adeci/cloudflare-tunnel";
      input = "self";
    };
    roles.default = {
      machines.leviathan = {
        settings = {
          tokenName = "adeci";
          tunnelName = "leviathan-services";
          ingress = {
            "buildbot.decio.us" = "http://localhost:80";
          };
        };
      };
    };
  };

}
