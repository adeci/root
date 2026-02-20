{ pkgs, wrappers, ... }:
{
  btop = wrappers.wrapperModules.btop.apply {
    inherit pkgs;

    "btop.conf".content = builtins.readFile ./btop.conf;

  };
}
