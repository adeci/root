{
  "adeci-net" = {
    module = {
      name = "@adeci/tailscale";
      input = "self";
    };
    roles.peer.tags.adeci-net = { };
    roles.peer.tags.adeci-net-work.settings.flags = [ "--accept-dns=false" ];
  };

  "adeci-net-ephemeral" = {
    module = {
      name = "@adeci/tailscale";
      input = "self";
    };
    roles.peer.tags = [ "adeci-net-ephemeral" ];
  };
}
