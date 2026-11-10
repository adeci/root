{
  wlib,
  ...
}:
{
  imports = [ wlib.wrapperModules.git ];
  settings = {
    init.defaultBranch = "main";
    pull.rebase = true;
    push.autoSetupRemote = true;
  };
}
