{ config, lib, ... }:
let
  cfg = config.adeci.homebrew;
in
{
  options.adeci.homebrew.enable = lib.mkEnableOption "Homebrew cask management";
  config = lib.mkIf cfg.enable {
    homebrew = {
      enable = true;
      onActivation.cleanup = "zap";
      taps = [
        "FelixKratz/formulae"
        "nikitabobko/tap"
      ];
      brews = [
        "FelixKratz/formulae/borders"
      ];
      casks = [
        "slack"
        "karabiner-elements"
        "nikitabobko/tap/aerospace"
      ];
    };
  };
}
