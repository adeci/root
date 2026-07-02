{
  buildbot = {
    module = {
      name = "@adeci/buildbot";
      input = "self";
    };

    roles.master.machines.leviathan.settings = {
      domain = "buildbot.decio.us";
      useHTTPS = true;
      buildSystems = [
        "aarch64-linux"
        "x86_64-linux"
      ];
      evalWorkerCount = 32;
      evalMaxMemorySize = 4096;
      admins = [ "adeci" ];
      github = {
        appId = 3002742;
        oauthId = "Iv23li39kVxcYTCXYahY";
        topic = "build-with-buildbot";
      };
    };

    roles.worker.machines.leviathan.settings = {
      systems = [ "x86_64-linux" ];
      cores = 32;
    };
  };
}
