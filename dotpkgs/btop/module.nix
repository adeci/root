{ pkgs, wrappers, ... }:
{
  btop =
    (wrappers.wrapperModules.btop.apply {
      inherit pkgs;

      "btop.conf".path = ./btop.conf;

    }).wrapper;
}
