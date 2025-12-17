{
  pkgs,
  wrappers,
  ...
}:
{
  waybar =
    (wrappers.wrapperModules.waybar.apply {
      inherit pkgs;
      settings = import ./settings.nix;
      "style.css".path = ./style.css;
    }).wrapper;
}
