{
  config,
  wlib,
  pkgs,
  lib,
  ...
}:
let
  inherit (pkgs.stdenv.hostPlatform) isLinux;

  atuinConfigDir = pkgs.writeTextDir "config.toml" (
    ''
      enter_accept = false
    ''
    + (
      if config.atuinSyncAddress != null then
        ''
          sync_address = "${config.atuinSyncAddress}"
          auto_sync = true
        ''
      else
        ''
          auto_sync = false
        ''
    )
  );
in
{
  imports = [ wlib.wrapperModules.zsh ];

  options = {
    extraInit = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Extra shell init appended to zshrc";
    };

    git = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = "git first on PATH; null leaves git to the system.";
    };

    tmux = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = "tmux on PATH; null leaves tmux to the system.";
    };

    atuinSyncAddress = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "http://atuin.example.com:8888";
      description = "Atuin server to sync shell history with; null keeps history local.";
    };
  };

  config = {
    hmSessionVariables = null;

    env = {
      WORDCHARS = "*?_-.[]~=&;!#$%^(){}<>";
      ATUIN_CONFIG_DIR = "${atuinConfigDir}";
    };

    prefixVar = [
      {
        data = [
          "PATH"
          ":"
          (lib.makeBinPath (
            lib.optional (config.git != null) config.git
            ++ [
              pkgs.ripgrep
              pkgs.fd
              pkgs.eza
              pkgs.bat
              pkgs.wget
              pkgs.unzip
              pkgs.fzf
              pkgs.jq

              pkgs.gh
              pkgs.jujutsu
              pkgs.nixpkgs-review
              pkgs.nix-output-monitor
              pkgs.smartmontools
              pkgs.socat
              pkgs.lsof
              pkgs.lazygit
              pkgs.screen
              pkgs.tio
              pkgs.pueue
              pkgs.xxd
              pkgs.radare2
              pkgs.gdb
              pkgs.python3
              pkgs.uv

              pkgs.zoxide
              pkgs.direnv
              pkgs.atuin
            ]
            ++ lib.optional (config.tmux != null) config.tmux
            ++ lib.optionals isLinux [
              pkgs.usbutils
              pkgs.unrar
              pkgs.dmidecode
              pkgs.pciutils
              pkgs.wl-clipboard
            ]
          ))
        ];
      }
    ];

    zshrc.content = # zsh
      ''
        typeset -gA zsh_pkgs=(
          completions ${pkgs.zsh-completions}
          autosuggestions ${pkgs.zsh-autosuggestions}
          fzf-tab ${pkgs.zsh-fzf-tab}
          autopair ${pkgs.zsh-autopair}
          pure ${pkgs.pure-prompt}
          zoxide ${pkgs.zoxide}
          direnv ${pkgs.direnv}
          atuin ${pkgs.atuin}
        )
        source ${./zshrc}

        ${lib.optionalString (config.extraInit != "") ''
          ${config.extraInit}
        ''}

        # Must be sourced last.
        source ${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

        ttyctl -f
      '';
  };
}
