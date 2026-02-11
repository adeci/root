{ pkgs, wrappers, ... }:
{
  git =
    (wrappers.wrapperModules.git.apply {
      inherit pkgs;

      settings = {
        user = {
          name = "adeci";
          email = "alex.decious@gmail.com";
        };
        init.defaultBranch = "main";
        pull.rebase = true;
        push.autoSetupRemote = true;
      };

      # true isolation from system's pre-existing git
      env.GIT_CONFIG_SYSTEM = "/dev/null";

    }).wrapper;
}
