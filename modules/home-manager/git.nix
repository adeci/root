_:
{
  programs.git = {
    enable = true;
    settings = {
      user.name = "adeci";
      user.email = "alex.decious@gmail.com";
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
    };
  };
}
