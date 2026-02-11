{ pkgs, wrappers, ... }:
{
  swaylock =
    (wrappers.wrapperModules.swaylock.apply {
      inherit pkgs;

      settings = {
        color = "000000";
        indicator-radius = 100;
        indicator-thickness = 25;
        inside-color = "00000000";
        ring-color = "7aa2f7";
        ring-ver-color = "bb9af7";
        ring-wrong-color = "f7768e";
        key-hl-color = "9ece6a";
        bs-hl-color = "f7768e";
        text-color = "c0caf5";
      };

    }).wrapper;
}
