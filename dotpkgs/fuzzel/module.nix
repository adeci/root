{ pkgs, wrappers, ... }:
{
  fuzzel =
    (wrappers.wrapperModules.fuzzel.apply {
      inherit pkgs;

      "fuzzel.ini".path = ./fuzzel.ini;

    }).wrapper;
}
