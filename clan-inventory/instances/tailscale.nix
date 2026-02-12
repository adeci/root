{
  "adeci-net" = {
    module = {
      name = "@adeci/tailscale";
      input = "self";
    };
    roles.peer = {
      tags."adeci-net" = { };
      settings = { };
    };
  };
}
