{
  pkgs,
  wrappers,
  ...
}:
{
  niri =
    (wrappers.wrapperModules.niri.apply {
      inherit pkgs;
      "config.kdl".path = ./config.kdl;
    }).wrapper;
}
