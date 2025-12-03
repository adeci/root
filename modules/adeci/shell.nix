{ inputs, pkgs, ... }:
let
  dotpkgs = inputs.adeci-dotpkgs.packages.${pkgs.stdenv.hostPlatform.system};
in
{

  environment.systemPackages = [
    pkgs.atuin
    dotpkgs.starship

    # clan autocompletions
    pkgs.python3Packages.argcomplete
  ];

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.fish = {

    enable = true;
    interactiveShellInit = ''

      # Disable greeting (override the default)
      set -g fish_greeting

      # Set default editor
      set -gx EDITOR nvim
      set -gx VISUAL nvim

      # Enable vi key bindings
      fish_vi_key_bindings

      # Keep cursor as block with blink (don't change in vi modes)
      set fish_cursor_default block blink
      set fish_cursor_insert block blink
      set fish_cursor_replace_one block blink
      set fish_cursor_visual block blink
      set fish_cursor_replace block blink
      set fish_cursor_external block blink

      # Disable vi key mode indicator
      function fish_mode_prompt; end

      # Git aliases
      alias gs='git status'
      alias gaa='git add -A'
      alias gc='git commit'
      alias gd='git diff'
      alias gds='git diff --staged'
      alias gp='git push'
      alias gll='git pull'
      alias gf='git fetch'
      alias glog='git log --oneline --graph'
      alias gco='git checkout'
      alias gb='git branch'
      alias lg='lazygit'

      # Editor aliases
      alias vi='nvim'
      alias vim='nvim'
      alias c='clear'
      alias ll='ls -la'
      alias la='ls -A'
      alias l='ls -CF'
      alias ..='cd ..'
      alias ...='cd ../..'
      alias ....='cd ../../..'
      alias md='mkdir -p'

      # Safety nets
      alias rm='rm -i'
      alias cp='cp -i'
      alias mv='mv -i'

      # Custom functions
      function mkcd
        mkdir -p $argv[1]
        and cd $argv[1]
      end

      # Initialize starship if available (prompt)
      if type -q starship
        starship init fish | source
      end

      # Clan completions - register when clan becomes available via direnv
      # Uses fish_prompt event to detect when clan enters PATH
      function __register_clan_completions --on-variable PATH
        if command -q clan && not set -q __clan_completions_registered
          ${pkgs.python3Packages.argcomplete}/bin/register-python-argcomplete --shell fish clan | source
          set -g __clan_completions_registered 1
        end
      end

      # Tokyo Night Theme
      set -g fish_color_autosuggestion 555
      set -g fish_color_cancel -r
      set -g fish_color_command 7aa2f7
      set -g fish_color_comment f7768e
      set -g fish_color_cwd 9ece6a
      set -g fish_color_cwd_root f7768e
      set -g fish_color_end 9ece6a
      set -g fish_color_error f7768e
      set -g fish_color_escape 7dcfff
      set -g fish_color_history_current --bold
      set -g fish_color_host normal
      set -g fish_color_host_remote e0af68
      set -g fish_color_keyword 7aa2f7
      set -g fish_color_match --background=7aa2f7
      set -g fish_color_normal normal
      set -g fish_color_operator 7dcfff
      set -g fish_color_option 7dcfff
      set -g fish_color_param 7dcfff
      set -g fish_color_quote e0af68
      set -g fish_color_redirection 7dcfff --bold
      set -g fish_color_search_match e0af68 --background=414868
      set -g fish_color_selection a9b1d6 --bold --background=414868
      set -g fish_color_status f7768e
      set -g fish_color_user 9ece6a
      set -g fish_color_valid_path --underline
      set -g fish_pager_color_background
      set -g fish_pager_color_completion normal
      set -g fish_pager_color_description e0af68 e0af68 -i
      set -g fish_pager_color_prefix normal --bold --underline
      set -g fish_pager_color_progress c0caf5 --background=7dcfff
      set -g fish_pager_color_secondary_background
      set -g fish_pager_color_secondary_completion
      set -g fish_pager_color_secondary_description
      set -g fish_pager_color_secondary_prefix
      set -g fish_pager_color_selected_background -r
      set -g fish_pager_color_selected_completion
      set -g fish_pager_color_selected_description
      set -g fish_pager_color_selected_prefix

    '';
  };
}
