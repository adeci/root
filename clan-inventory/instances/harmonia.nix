{
  harmonia = {
    module = {
      name = "@adeci/harmonia";
      input = "self";
    };
    roles.server.machines.leviathan = { };
    roles.client.tags = [ "adeci-net" ];
  };
}
