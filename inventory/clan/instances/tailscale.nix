{
  "adeci-net" = {
    module = {
      name = "@adeci/tailscale";
      input = "self";
    };
    roles.peer = {
      tags = [ "adeci-net" ];
      settings = {
        accept-routes = true;
        accept-dns = false;
        tailnet-domain = "cymric-daggertooth.ts.net";
      };
      machines.janus.settings = {
        advertise-routes = [
          "10.99.0.0/24"
          "10.10.0.0/24"
          "10.20.0.0/24"
          "10.30.0.0/24"
        ];
      };
    };
  };

  "adeci-net-ephemeral" = {
    module = {
      name = "@adeci/tailscale";
      input = "self";
    };
    roles.peer = {
      tags = [ "adeci-net-ephemeral" ];
      settings = { };
    };
  };
}
