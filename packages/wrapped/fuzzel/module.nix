{ pkgs, wrappers, ... }:
{
  fuzzel = wrappers.wrapperModules.fuzzel.apply {
    inherit pkgs;
    settings = {
      main.font = "CaskaydiaMono Nerd Font:size=14";
      colors = {
        background = "16161Eff";
        text = "787C99ff";
        prompt = "7AA2F7ff";
        input = "CBCCD1ff";
        match = "F7768Eff";
        selection = "2F3549ff";
        selection-text = "CBCCD1ff";
        selection-match = "F7768Eff";
        border = "444B6Aff";
      };
    };
  };
}
