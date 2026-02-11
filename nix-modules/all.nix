{ inputs, pkgs, ... }:
let
  dotpkgs = import ../dotpkgs {
    inherit pkgs;
    wrappers = inputs.adeci-wrappers;
    nixvim = inputs.nixvim;
  };
in
{
  nixpkgs.config.allowUnfree = true;

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  environment.systemPackages =
    with pkgs;
    [
      git
      kitty.terminfo
      ripgrep
      fd
      eza
      bat
      wget
      unzip
      unrar
      fzf
      tmux # TODO: wrap me!
    ]
    ++ [
      dotpkgs.btop
      dotpkgs.nixvim
    ];

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };
}
