_: {
  homebrew = {
    enable = true;
    onActivation.cleanup = "zap";
    taps = [
      "homebrew/core"
      "homebrew/cask"
      "FelixKratz/formulae"
      "nikitabobko/tap"
    ];
    brews = [
      "FelixKratz/formulae/borders"
    ];
    casks = [
      "raycast"
      "karabiner-elements"
      "nikitabobko/tap/aerospace"
      "scroll-reverser"
    ];
  };
}
