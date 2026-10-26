{
  wrappers = {
    big-htop = {
      path = ./big-htop;
    };

    btop = {
      path = ./btop;
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

    nvim = {
      path = ./nvim;
    };

    nvim-dev = {
      path = ./nvim-dev;
    };

    tmux = {
      path = ./tmux;
    };

    zsh = {
      path = ./zsh;
    };
  };

  packages = {
    cheat = {
      path = ./cheat;
      systems = [ "x86_64-linux" ];
    };

    clan-cli = {
      path = ./clan-cli;
    };

    element-desktop = {
      path = ./element-desktop;
      systems = [ "x86_64-linux" ];
      checks = false;
    };

    handy = {
      path = ./handy;
      systems = [
        "aarch64-darwin"
        "x86_64-linux"
      ];
      checks = false;
    };

    # Uses systemd user units.
    thaw = {
      path = ./thaw;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
    };

    prusa-slicer = {
      path = ./prusa-slicer;
      systems = [ "x86_64-linux" ];
      checks = false;
    };

    pexpect-cli = {
      path = ./pexpect-cli;
    };

    pi-profile = {
      path = ./pi-profile;
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

    update-locks = {
      path = ./update-locks;
    };

    vencord = {
      path = ./vencord;
      systems = [ "x86_64-linux" ];
      checks = false;
    };

    vesktop = {
      path = ./vesktop;
      systems = [ "x86_64-linux" ];
      checks = false;
    };

    zipline = {
      path = ./zipline;
      systems = [ "x86_64-linux" ];
      checks = false;
    };
  };
}
