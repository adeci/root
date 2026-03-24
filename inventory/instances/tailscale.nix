{
  "adeci-net" = {
    module = {
      name = "@adeci/tailscale";
      input = "self";
    };
    roles.peer = {
      tags = [ "adeci-net" ];
      settings = { };
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
