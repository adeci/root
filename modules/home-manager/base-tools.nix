{
  config,
  lib,
  pkgs,
  dotpkgs,
  ...
}:
let
  cfg = config.adeci.base-tools;
in
{
  options.adeci.base-tools.enable = lib.mkEnableOption "base CLI tools";
  config = lib.mkIf cfg.enable {
    home.packages =
      with pkgs;
      [
        ripgrep
        fd
        eza
        bat
        wget
        unzip
        fzf
        tmux
        git
      ]
      ++ [
        dotpkgs.btop.wrapper
        dotpkgs.nixvim
      ]
      ++ lib.optionals pkgs.stdenv.isLinux (
        with pkgs;
        [
          usbutils
          unrar
        ]
      );
  };
}
