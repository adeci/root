{
  config,
  lib,
  pkgs,
  ...
}:
{
  home.packages = [
    pkgs.fzf
  ];

  programs.zsh = {
    enable = true;

    autosuggestion = {
      enable = true;
      highlight = "fg=242";
    };
    syntaxHighlighting.enable = true;
    enableCompletion = true;

    history = {
      size = 10000;
      save = 10000;
      ignoreDups = true;
      ignoreSpace = true;
      expireDuplicatesFirst = true;
      extended = true;
      share = true;
    };

    shellAliases = {
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
      nrb = "noglob nix build --max-jobs 0 --builders @/etc/nix/machines";
    };

    plugins = [
      {
        name = "fzf-tab";
        src = pkgs.zsh-fzf-tab;
        file = "share/fzf-tab/fzf-tab.plugin.zsh";
      }
      {
        name = "zsh-autopair";
        src = pkgs.zsh-autopair;
        file = "share/zsh/zsh-autopair/autopair.zsh";
      }
    ];

    initContent = lib.mkMerge [
      # Extra completion definitions (must be in fpath before compinit)
      (lib.mkBefore ''
        fpath+=(${pkgs.zsh-completions}/share/zsh/site-functions)
      '')

      ''
        # Shell options
        setopt auto_cd
        setopt no_beep
        setopt pushd_ignore_dups
        setopt complete_in_word
        setopt auto_name_dirs
        setopt multios

        # Vi keybindings
        bindkey -v
        export KEYTIMEOUT=1

        # Always use blinking block cursor
        autoload -Uz add-zle-hook-widget
        _cursor_block() { print -n '\e[1 q' > /dev/tty; }
        add-zle-hook-widget zle-line-init _cursor_block

        # Edit command in $EDITOR with Ctrl-X Ctrl-E
        autoload edit-command-line
        zle -N edit-command-line
        bindkey '^X^e' edit-command-line
        bindkey '^[[3~' delete-char

        # Pure prompt
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
        zstyle :prompt:pure:user color blue
        zstyle :prompt:pure:host color green
        zstyle :prompt:pure:prompt:success color green
        zstyle :prompt:pure:prompt:error color red
        zstyle :prompt:pure:execution_time color yellow
        prompt pure

        # Non-zero exit code in right prompt
        RPS1='%(?.%F{magenta}.%F{red}(%?%) %F{magenta})'

        # OSC 133 prompt marks (semantic zones for tmux/terminal scrollback)
        precmd() { print -Pn "\e]133;A\e\\"; }

        # fzf-tab configuration
        ${lib.optionalString config.programs.tmux.enable ''
          zstyle ':fzf-tab:*' fzf-command ftb-tmux-popup
        ''}
        zstyle ':completion:*:git-checkout:*' sort false
        zstyle ':completion:*:descriptions' format '[%d]'
        zstyle ':completion:*' list-colors ''${(s.:.)LS_COLORS}
        zstyle ':completion:*' menu no
        zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls -1 --color=always $realpath'
        zstyle ':fzf-tab:*' switch-group '<' '>'

        # Environment
        export EDITOR=nvim
        export VISUAL=nvim
        export WORDCHARS='*?_-.[]~=&;!#$%^(){}<>'

        # Functions
        mkcd() { mkdir -p "$1" && cd "$1"; }

        yy() {
          if [[ "$(uname)" == "Darwin" ]]; then
            cat "$1" | pbcopy
          else
            cat "$1" | wl-copy
          fi
        }

        levtop() { ssh leviathan -t htop; }

        update-claude-code() {
          nix-shell maintainers/scripts/update.nix \
            --argstr commit true \
            --arg predicate '(path: pkg: builtins.elem path [["claude-code"] ["claude-code-bin"] ["vscode-extensions" "anthropic" "claude-code"]])'
        }

        ${lib.optionalString config.programs.tmux.enable ''
          # Tmux session manager
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

          # Desktop notification (works inside tmux)
          term-notify() {
            local title="$1" message="$2"
            if [[ -n "$TMUX" ]]; then
              printf "\x1bPtmux;\x1b\x1b]777;notify;%s;%s\a\x1b\\" "$title" "$message"
            else
              printf "\x1b]777;notify;%s;%s\a" "$title" "$message"
            fi
          }

          # Downgrade TERM inside tmux for SSH compatibility
          if [[ -n "$TMUX" ]] && (( $+commands[tput] )); then
            if TERM=tmux-256color tput longname &>/dev/null; then
              export TERM=tmux-256color
            fi
          fi
        ''}

        # Atuin — bind Ctrl-R and up arrow
        if (( $+commands[atuin] )); then
          export ATUIN_NOBIND="true"
          eval "$(atuin init zsh)"
          bindkey '^r' _atuin_search_widget
          bindkey '^[[A' _atuin_search_widget
          bindkey '^[OA' _atuin_search_widget
        fi

        # Clan completions
        if (( $+commands[clan] )); then
          eval "$(${pkgs.python3Packages.argcomplete}/bin/register-python-argcomplete --shell zsh clan)"
        fi

        # Direnv
        if (( $+commands[direnv] )); then
          eval "$(direnv hook zsh)"
        fi

        # Reset terminal to sane defaults after commands
        ttyctl -f
      ''
    ];
  };
}
