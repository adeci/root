{ pkgs, wrappers, ... }:
{
  mako =
    (wrappers.wrapperModules.mako.apply {
      inherit pkgs;

      configFile.path = ./config;

    }).wrapper;
}
