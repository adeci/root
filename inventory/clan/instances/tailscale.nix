{
  "adeci-net" = {
    module = {
      name = "@adeci/tailscale";
      input = "self";
    };
    roles.peer = {
      tags = [ "adeci-net" ];
      settings = {
        accept-dns = false;
        tailnet-domain = "cymric-daggertooth.ts.net";
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
