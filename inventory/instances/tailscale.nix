{
  "adeci-net" = {
    module = {
      name = "@onix/tailscale";
      input = "self";
    };
    roles.peer = {
      tags."adeci-net" = { };
      settings = { };
    };
  };
}
