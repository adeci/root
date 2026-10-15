{
  wlib,
  pkgs,
  ...
}:
{
  imports = [ wlib.wrapperModules.tmux ];

  prefix = "C-Space";
  baseIndex = 1;
  escapeTime = 0;
  historyLimit = 50000;
  mouse = true;
  modeKeys = "vi";
  terminal = "tmux-256color";
  aggressiveResize = true;
  disableConfirmationPrompt = false;

  plugins = [
    {
      plugin = pkgs.tmuxPlugins.fingers;
      configBefore = ''
        set -g @fingers-key f
        set -g @fingers-enabled-builtin-patterns url
      '';
    }
  ];

  configBefore = ''
    # --- Terminal capabilities ---
    set -ga terminal-features "*:hyperlinks"
    set -g extended-keys on
    set -g extended-keys-format csi-u
    set -g set-clipboard on
    set -g set-titles on
    set-option -g set-titles-string "#H"

    # --- Window behavior ---
    set-option -g renumber-windows on
    set -g display-time 4000
    set -g status-interval 5

    # --- Environment forwarding on reattach ---
    set -g update-environment 'DISPLAY SSH_ASKPASS SSH_AGENT_PID SSH_AUTH_SOCK SSH_CONNECTION SSH_TTY WINDOWID XAUTHORITY'

    # New panes re-read the current system's environment
    set-environment -gu __NIX_DARWIN_SET_ENVIRONMENT_DONE
    set-environment -gu __NIXOS_SET_ENVIRONMENT_DONE
  '';

  configAfter = ''
    # --- Keybindings ---

    # Pane navigation — vim keys
    bind h select-pane -L
    bind j select-pane -D
    bind k select-pane -U
    bind l select-pane -R

    # Window navigation — shift vim keys
    bind H previous-window
    bind L next-window

    # Intuitive splits (preserve working directory)
    bind - split-window -c "#{pane_current_path}"
    bind | split-window -h -c "#{pane_current_path}"
    bind '"' split-window -c "#{pane_current_path}"
    bind % split-window -h -c "#{pane_current_path}"
    bind c new-window -c "#{pane_current_path}"

    # View scrollback (copy mode)
    bind v copy-mode

    # Session management
    bind S command-prompt -p "New session:" "new-session -s '%%'"
    bind Tab switch-client -l

    # Confirm before killing a window
    bind-key K confirm kill-window

    # Copy and clear the selection without leaving copy mode
    bind-key -T copy-mode-vi y send-keys -X copy-selection

    # --- Pane resize requires Ctrl+drag ---
    unbind -n MouseDrag1Border
    bind -n C-MouseDrag1Border resize-pane -M

    # --- Tokyo Night status bar ---
    set -g status-style bg=default
    set -g status-left-length 90
    set -g status-justify centre

    set-option -gq status-left '#[fg=#1a1b26,bg=#9ece6a,bold] #S #[fg=#9ece6a,bg=default,nobold,nounderscore,noitalics]'
    set-option -gq status-right ""
    set-option -gq window-status-format '#[fg=#565f89,bg=default] #I  #W '
    set-option -gq window-status-current-format '#[fg=#1a1b26,bg=#7aa2f7,bold] #I  #W #[fg=#7aa2f7,bg=default,nobold]'
  '';
}
