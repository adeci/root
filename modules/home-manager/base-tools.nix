{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  cfg = config.adeci.base-tools;
  packages = self.packages.${pkgs.stdenv.hostPlatform.system};
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
        packages.btop
        packages.nixvim
      ]
      ++ lib.optionals pkgs.stdenv.isLinux [
        packages.kitty
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
