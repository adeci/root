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
      # leviathan is shared with other users and the LLM host; keep CI bounded.
      evalWorkerCount = 8;
      evalMaxMemorySize = 4096;
      buildConcurrency = 8;
      admins = [ "github:adeci" ];
      github = {
        appId = 5474567;
        oauthId = "Iv23liPuk6XhuDT6Owtz";
        topic = "build-with-buildbot";
      };
    };
  };
}
