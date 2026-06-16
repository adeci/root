{
  restic = {
    module = {
      name = "@adeci/restic";
      input = "self";
    };

    roles.client.machines = {
      sequoia = { };
      leviathan = { };
    };
  };
}
