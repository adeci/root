{ wlib, ... }:
{
  imports = [ wlib.wrapperModules.git ];

  config = {
    settings = {
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
    };
  };
}
