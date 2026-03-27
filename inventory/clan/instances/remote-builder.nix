{
  builders = {
    module = {
      name = "@adeci/remote-builder";
      input = "self";
    };
    roles.server.machines.leviathan = {
      settings = {
        systems = [
          "x86_64-linux"
          "i686-linux"
        ];
        maxJobs = 16;
        speedFactor = 10;
      };
    };
    roles.client.machines = {
      aegis = { };
      praxis = { };
    };
  };
}
