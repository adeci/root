{
  # Named buildbot so the GitHub App secrets and domain carry over.
  buildbot = {
    module = {
      name = "@adeci/nixbot";
      input = "self";
    };

    roles.server.machines.leviathan.settings = {
      domain = "buildbot.decio.us";
      buildSystems = [
        "aarch64-linux"
        "x86_64-linux"
      ];
      evalWorkerCount = 32;
      evalMaxMemorySize = 4096;
      admins = [ "github:adeci" ];
      # Keep buildbot-era check names for existing branch protection.
      statusContextPrefix = "buildbot";
      github = {
        appId = 3002742;
        oauthId = "Iv23li39kVxcYTCXYahY";
        topic = "build-with-buildbot";
      };
    };
  };
}
