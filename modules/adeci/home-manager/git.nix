{
  programs.git = {
    enable = true;

    # Using the new settings format (replaces extraConfig in newer home-manager)
    settings = {
      user.name = "adeci";
      user.email = "alex.decious@gmail.com";
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
    };
  };
}
