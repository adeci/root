{
  restic = {
    module = {
      name = "@adeci/restic";
      input = "self";
    };

    roles.client.machines = {
      conduit = { };
      sequoia = { };
      leviathan = { };
      janus = { };
    };
  };
}
