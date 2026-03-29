{
  config,
  wlib,
  pkgs,
  lib,
  inputs,
  ...
}:
let
  inherit (pkgs.stdenv) isLinux;

  wrappedGit = inputs.self.wrappers.git.wrap { inherit pkgs; };
  wrappedTmux = inputs.self.wrappers.tmux.wrap { inherit pkgs; };

  llm-agents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
  mics-skills = inputs.mics-skills.packages.${pkgs.stdenv.hostPlatform.system};

  atunConfigDir = pkgs.runCommand "atuin-config" { } ''
    mkdir -p $out
    cat > $out/config.toml <<'EOF'
    enter_accept = false
    sync_address = "http://sequoia:8888"
    auto_sync = true
    EOF
  '';
in
{
  imports = [ wlib.wrapperModules.zsh ];

  options.withLLMTools = lib.mkEnableOption "LLM tools (pi, claude-code, etc.)";

  options.extraInit = lib.mkOption {
    type = lib.types.lines;
    default = "";
    description = "Extra shell init appended to zshrc";
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
            [
              # Wrapped packages
              wrappedGit
              inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.nixvim

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
              pkgs.socat
              pkgs.lsof
              pkgs.lazygit
              pkgs.screen
              pkgs.tio
              pkgs.pueue
              pkgs.xxd
              pkgs.radare2
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
            ++ lib.optionals config.withLLMTools [
              llm-agents.claude-code
              llm-agents.pi
              llm-agents.ccusage
              llm-agents.ccusage-pi
              llm-agents.workmux
              llm-agents.openspec
              mics-skills.kagi-search
              mics-skills.context7-cli
              mics-skills.browser-cli
              mics-skills.pexpect-cli
              mics-skills.screenshot-cli
            ]
          ))
        ];
      }
    ];

    zshAliases = {
      gs = "git status";
      gaa = "git add -A";
      gc = "git commit";
      gd = "git diff";
      gds = "git diff --staged";
      gp = "git push";
      gll = "git pull";
      gf = "git fetch";
      glog = "git log --oneline --graph";
      gco = "git checkout";
      gb = "git branch";
      lg = "lazygit";
      vi = "nvim";
      vim = "nvim";
      c = "clear";
      ls = "eza --icons --smart-group --time-style relative";
      tree = "eza --tree --icons";
      ll = "eza --icons --smart-group --time-style relative -la";
      la = "eza --icons --smart-group --time-style relative -a";
      l = "eza --icons --smart-group --time-style relative";
      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../..";
      md = "mkdir -p";
      rm = "rm -i";
      cp = "cp -i";
      mv = "mv -i";
      nix = "noglob nix";
      nom = "noglob nom";
      curl = "noglob curl";
      wget = "noglob wget";
      nrb = "noglob nom build --max-jobs 0 --builders @/etc/nix/machines";
      rz = "exec zsh";
    };

    zshrc.content = # zsh
      ''
        # ── History ──────────────────────────────────────────────────────
        HISTFILE="$HOME/.zsh_history"
        HISTSIZE=10000
        SAVEHIST=10000
        setopt HIST_IGNORE_DUPS
        setopt HIST_IGNORE_SPACE
        setopt HIST_EXPIRE_DUPS_FIRST
        setopt EXTENDED_HISTORY
        setopt SHARE_HISTORY

        # ── Completions ──────────────────────────────────────────────────
        fpath+=(${pkgs.zsh-completions}/share/zsh/site-functions)
        autoload -Uz compinit && compinit

        # ── Plugins ──────────────────────────────────────────────────────
        source ${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh
        ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=242"

        source ${pkgs.zsh-fzf-tab}/share/fzf-tab/fzf-tab.plugin.zsh

        source ${pkgs.zsh-autopair}/share/zsh/zsh-autopair/autopair.zsh
        autopair-init

        # ── Shell integrations ─────────────────────────────────────────
        eval "$(${pkgs.zoxide}/bin/zoxide init zsh)"
        eval "$(${pkgs.direnv}/bin/direnv hook zsh)"
        eval "$(${pkgs.atuin}/bin/atuin init zsh)"

        # ── Shell options ────────────────────────────────────────────────
        setopt auto_cd
        setopt no_beep
        setopt pushd_ignore_dups
        setopt complete_in_word
        setopt auto_name_dirs
        setopt multios

        # ── Vi keybindings ───────────────────────────────────────────────
        bindkey -v
        export KEYTIMEOUT=1

        autoload -Uz add-zle-hook-widget
        _cursor_block() { print -n '\e[1 q' > /dev/tty; }
        add-zle-hook-widget zle-line-init _cursor_block

        autoload edit-command-line
        zle -N edit-command-line
        bindkey '^X^e' edit-command-line
        bindkey '^[[3~' delete-char

        # ── Pure prompt ──────────────────────────────────────────────────
        fpath+=(${pkgs.pure-prompt}/share/zsh/site-functions)
        autoload -U promptinit; promptinit
        PURE_GIT_UNTRACKED_DIRTY=0
        PURE_GIT_PULL=0
        PURE_CMD_MAX_EXEC_TIME=4
        PURE_PROMPT_SYMBOL="%(?.%F{green}.%F{red})❯%f"
        zstyle :prompt:pure:path color cyan
        zstyle :prompt:pure:git:branch color magenta
        zstyle :prompt:pure:git:branch:cached color red
        zstyle :prompt:pure:git:dirty color yellow
        zstyle :prompt:pure:git:arrow color cyan
        zstyle :prompt:pure:user color '#7aa2f7'
        zstyle :prompt:pure:host color '#9ece6a'
        zstyle :prompt:pure:prompt:success color green
        zstyle :prompt:pure:prompt:error color red
        zstyle :prompt:pure:execution_time color yellow
        prompt pure

        prompt_pure_state[username]='%F{#7aa2f7}%n%f%F{#9ece6a}@%m%f'

        RPS1='%(?.%F{magenta}.%F{red}(%?%) %F{magenta})'

        # OSC 133 prompt marks
        precmd() { print -Pn "\e]133;A\e\\"; }

        # ── fzf-tab configuration ────────────────────────────────────────
        if (( $+commands[tmux] )); then
          zstyle ':fzf-tab:*' fzf-command ftb-tmux-popup
        fi
        zstyle ':completion:*:git-checkout:*' sort false
        zstyle ':completion:*:descriptions' format '[%d]'
        zstyle ':completion:*' list-colors ''${(s.:.)LS_COLORS}
        zstyle ':completion:*' menu no
        zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls -1 --color=always $realpath'
        zstyle ':fzf-tab:*' switch-group '<' '>'

        # ── Functions ────────────────────────────────────────────────────
        mkcd() { mkdir -p "$1" && cd "$1"; }

        yy() {
          if [[ "$(uname)" == "Darwin" ]]; then
            cat "$1" | pbcopy
          else
            cat "$1" | wl-copy
          fi
        }

        ekh() {
          if [[ $# -eq 0 ]]; then
            nvim ~/.ssh/known_hosts
          else
            local kh=~/.ssh/known_hosts
            for pattern in "$@"; do
              local matches=$(grep -c "$pattern" "$kh" 2>/dev/null)
              if (( matches > 0 )); then
                grep --color=always "$pattern" "$kh"
                sed -i "/$pattern/d" "$kh"
                echo "Removed $matches entry(s) matching '$pattern'"
              else
                echo "No entries matching '$pattern'"
              fi
            done
          fi
        }

        levtop() { ssh leviathan -t htop; }

        update-claude-code() {
          nix-shell maintainers/scripts/update.nix \
            --argstr commit true \
            --arg predicate '(path: pkg: builtins.elem path [["claude-code"] ["claude-code-bin"] ["vscode-extensions" "anthropic" "claude-code"]])'
        }

        # ── Tmux integration ─────────────────────────────────────────────
        if (( $+commands[tmux] )); then
          tms() {
            if [[ -z "$1" ]]; then
              if [[ -n "$TMUX" ]]; then
                tmux choose-tree -s
              elif tmux list-sessions &>/dev/null; then
                tmux attach-session
              else
                tmux new-session
              fi
            else
              if [[ -n "$TMUX" ]]; then
                tmux new-session -d -s "$1" &>/dev/null
                tmux switch-client -t "$1"
              else
                tmux new-session -A -s "$1"
              fi
            fi
          }

          term-notify() {
            local title="$1" message="$2"
            if [[ -n "$TMUX" ]]; then
              printf "\x1bPtmux;\x1b\x1b]777;notify;%s;%s\a\x1b\\" "$title" "$message"
            else
              printf "\x1b]777;notify;%s;%s\a" "$title" "$message"
            fi
          }

          if [[ -n "$TMUX" ]] && (( $+commands[tput] )); then
            if TERM=tmux-256color tput longname &>/dev/null; then
              export TERM=tmux-256color
            fi
          fi
        fi

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
