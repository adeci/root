{
  sshd = {
    module = {
      name = "sshd";
      input = "clan-core";
    };
    roles.server.tags = [ "adeci-net" ];
    roles.client.tags = [ "adeci-net" ];
  };
}
