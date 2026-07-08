{
  builders = {
    module = {
      name = "@adeci/remote-builder";
      input = "self";
    };
    roles.server.machines = {
      bramble.settings = {
        systems = [ "aarch64-linux" ];
        maxJobs = 2;
        speedFactor = 1;
        supportedFeatures = [ ];
      };

      leviathan.settings = {
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
      bramble = { };
      leviathan = { };
      praxis = { };
    };
  };
}
