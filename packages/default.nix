{
  wrappers = {
    big-htop = {
      path = ./big-htop;
    };

    btop = {
      path = ./btop;
    };

    desktop-demo = {
      path = ./desktop-demo;
      systems = [ "x86_64-linux" ];
      checks = false;
    };

    git = {
      path = ./git;
    };

    kitty = {
      path = ./kitty;
    };

    niri = {
      path = ./niri;
      systems = [ "x86_64-linux" ];
    };

    noctalia-shell = {
      path = ./noctalia-shell;
      systems = [ "x86_64-linux" ];
    };

    tmux = {
      path = ./tmux;
    };

    zsh = {
      path = ./zsh;
    };
  };

  packages = {
    agent-browser = {
      path = ./agent-browser;
    };

    cheat = {
      path = ./cheat;
      systems = [ "x86_64-linux" ];
    };

    element-desktop = {
      path = ./element-desktop;
      systems = [ "x86_64-linux" ];
      checks = false;
    };

    handy = {
      path = ./handy;
      systems = [ "aarch64-darwin" ];
      checks = false;
    };

    niri-display = {
      path = ./niri-display;
      systems = [ "x86_64-linux" ];
    };

    niri-reload = {
      path = ./niri-reload;
      systems = [ "x86_64-linux" ];
    };

    noctalia-shell-plugin-tests = {
      path = ./noctalia-shell/test.nix;
      systems = [ "x86_64-linux" ];
    };

    prusa-slicer = {
      path = ./prusa-slicer;
      systems = [ "x86_64-linux" ];
      checks = false;
    };

    pexpect-cli = {
      path = ./pexpect-cli;
    };

    routeros-netinstall-cap-ax = {
      path = ./routeros-netinstall/cap-ax;
      systems = [ "x86_64-linux" ];
    };

    routeros-netinstall-crs310 = {
      path = ./routeros-netinstall/crs310;
      systems = [ "x86_64-linux" ];
    };

    routeros-netinstall-crs328 = {
      path = ./routeros-netinstall/crs328;
      systems = [ "x86_64-linux" ];
    };

    sdwire-cli = {
      path = ./sdwire-cli;
      systems = [ "x86_64-linux" ];
    };

    signal-desktop = {
      path = ./signal-desktop;
      systems = [ "x86_64-linux" ];
      checks = false;
    };

    vesktop = {
      path = ./vesktop;
      systems = [ "x86_64-linux" ];
      checks = false;
    };
  };
}
