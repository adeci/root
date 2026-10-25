{
  config,
  wlib,
  pkgs,
  lib,
  self,
  ...
}:
let
  inherit (pkgs.stdenv.hostPlatform) isLinux;

  defaultGit = self.wrappers.git.wrap { inherit pkgs; };
  wrappedTmux = self.wrappers.tmux.wrap { inherit pkgs; };

  atunConfigDir = pkgs.writeTextDir "config.toml" (
    ''
      enter_accept = false
    ''
    + (
      if config.atuinSync then
        ''
          sync_address = "http://sequoia.cymric-daggertooth.ts.net:8888"
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
  imports = [
    wlib.wrapperModules.zsh
    ../thaw/wrapper.nix
  ];

  options.extraInit = lib.mkOption {
    type = lib.types.lines;
    default = "";
    description = "Extra shell init appended to zshrc";
  };

  options.git = lib.mkOption {
    type = lib.types.nullOr lib.types.package;
    default = defaultGit;
    description = "git first on PATH; null leaves git to the system.";
  };

  options.atuinSync = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Sync shell history through sequoia's Atuin server.";
  };

  config = {
    hmSessionVariables = null;

    env = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      WORDCHARS = "*?_-.[]~=&;!#$%^(){}<>";
      ATUIN_CONFIG_DIR = "${atunConfigDir}";
    };

    prefixVar = [
      {
        data = [
          "PATH"
          ":"
          (lib.makeBinPath (
            lib.optional (config.git != null) config.git
            ++ [
              # Wrapped packages
              self.packages.${pkgs.stdenv.hostPlatform.system}.nixvim

              # Core CLI tools
              pkgs.ripgrep
              pkgs.fd
              pkgs.eza
              pkgs.bat
              pkgs.wget
              pkgs.unzip
              pkgs.fzf
              pkgs.jq

              # Dev tools
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

              # Shell integration
              pkgs.zoxide
              pkgs.direnv
              pkgs.atuin
              wrappedTmux
            ]
            ++ lib.optionals isLinux [
              pkgs.usbutils
              pkgs.unrar
              pkgs.dmidecode
              pkgs.pciutils
            ]
          ))
        ];
      }
    ];

    thaw.files.zshrc = ./zshrc;

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
        source "''$${config.thaw.var}/zshrc"

        ${lib.optionalString (config.extraInit != "") ''
          # ── Extra init ───────────────────────────────────────────────────
          ${config.extraInit}
        ''}

        # ── Syntax highlighting (must be sourced last) ───────────────────
        source ${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

        ttyctl -f
      '';
  };
}
