{
  nixbot = {
    module = {
      name = "@adeci/nixbot";
      input = "self";
    };

    roles.server.machines.leviathan.settings = {
      domain = "nixbot.decio.us";
      buildSystems = [
        "aarch64-linux"
        "x86_64-linux"
      ];
      evalWorkerCount = 32;
      evalMaxMemorySize = 4096;
      admins = [ "github:adeci" ];
      github = {
        appId = 3002742;
        oauthId = "Iv23li39kVxcYTCXYahY";
        topic = "build-with-buildbot";
      };
    };
  };
}
