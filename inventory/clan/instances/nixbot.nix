{
  nixbot = {
    module = {
      name = "@adeci/nixbot";
      input = "self";
    };

    roles.server.machines.leviathan.settings = {
      domain = "nixbot.decio.us";
      # aarch64 only builds on bramble (Pi 4) and times out.
      buildSystems = [ "x86_64-linux" ];
      # leviathan is shared with other users and the LLM host; keep CI bounded.
      evalWorkerCount = 8;
      evalMaxMemorySize = 4096;
      buildConcurrency = 8;
      admins = [
        "github:adeci"
        "github:fzakaria"
      ];
      prApproval = {
        enable = true;
        trustedAssociations = [
          "OWNER"
          "MEMBER"
          "COLLABORATOR"
        ];
      };
      github = {
        appId = 5474567;
        oauthId = "Iv23liPuk6XhuDT6Owtz";
        userAllowlist = [
          "adeci"
          "ddeci"
          "fzakaria"
        ];
      };
      effectSecrets."github:fzakaria/rewindvm" = [ "cachix" ];
    };
  };
}
