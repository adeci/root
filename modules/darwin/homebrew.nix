_: {
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
      "raycast"
      "karabiner-elements"
      "nikitabobko/tap/aerospace"
      "scroll-reverser"
    ];
  };
}
