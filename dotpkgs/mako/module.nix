{ pkgs, wrappers, ... }:
{
  mako = (
    wrappers.wrapperModules.mako.apply {
      inherit pkgs;
      settings = {
        font = "CaskaydiaMono Nerd Font 11";
        background-color = "#1A1B26";
        text-color = "#787C99";
        border-color = "#444B6A";
        progress-color = "over #7AA2F7";
        border-size = 2;
        border-radius = 4;
        width = 300;
        padding = 10;
        default-timeout = 5000;
      };
    }
  );
}
