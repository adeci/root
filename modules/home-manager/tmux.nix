{ pkgs, ... }:
{
  programs.tmux = {
    enable = true;

    # Ergonomics
    prefix = "C-Space";
    baseIndex = 1;
    escapeTime = 0;
    historyLimit = 50000;
    mouse = true;
    keyMode = "vi"; # vi keys in copy mode
    terminal = "tmux-256color";
    focusEvents = true;
    aggressiveResize = true;

    # tmux-thumbs via home-manager plugin system (no TPM)
    plugins = [
      {
        plugin = pkgs.tmuxPlugins.tmux-thumbs;
        extraConfig = ''
          # Activation
          unbind f
          set -g @thumbs-key f

          # Actions: lowercase opens, uppercase pastes
          set -g @thumbs-command "command -v xdg-open {} && xdg-open {} || command -v open && open {}"
          set -g @thumbs-upcase-command "tmux set-buffer -w -- {} && tmux paste-buffer"

          # Display options
          set -g @thumbs-contrast 1
          set -g @thumbs-unique 1
          set -g @thumbs-reverse enabled

          # Custom Nix hash regex: SRI hashes, git hashes, Nix store hashes
          set -g @thumbs-regexp-1 '(sha256-[0-9a-zA-z=/+]{44}|[0-9a-f]{7,40}|[0-9a-z]{52})'

          # Tokyo Night hint colors
          set -g @thumbs-bg-color '#565f89'
          set -g @thumbs-fg-color '#c0caf5'
          set -g @thumbs-hint-bg-color '#e0af68'
          set -g @thumbs-hint-fg-color '#1a1b26'
          set -g @thumbs-select-bg-color '#7aa2f7'
          set -g @thumbs-select-fg-color '#1a1b26'
        '';
      }
    ];

    extraConfig = ''
      # --- Terminal capabilities ---
      set-option -sa terminal-overrides ",*:Tc"
      set -ga terminal-features "*:hyperlinks"
      set -ga terminal-features "*:osc133"
      set -g extended-keys on
      set -g allow-passthrough on
      set -g set-clipboard on
      set -g set-titles on
      set-option -g set-titles-string "#H"

      # --- Command prompt uses emacs keys (even with vi copy mode) ---
      set -g status-keys emacs

      # --- Window behavior ---
      set-option -g renumber-windows on
      set -g visual-activity on
      set -g display-time 4000
      set -g status-interval 5

      # --- Environment forwarding on reattach ---
      set -g update-environment 'DISPLAY SSH_ASKPASS SSH_AGENT_PID SSH_AUTH_SOCK SSH_CONNECTION SSH_TTY WINDOWID XAUTHORITY TERM'

      # --- Keybindings ---

      # Pane navigation — vim keys + arrow keys (arrows work by default)
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
      # Keep defaults too
      bind '"' split-window -c "#{pane_current_path}"
      bind % split-window -h -c "#{pane_current_path}"
      bind c new-window -c "#{pane_current_path}"

      # View scrollback (copy mode)
      bind v copy-mode

      # Session management
      bind S command-prompt -p "New session:" "new-session -s '%%'"
      bind Tab switch-client -l

      # Reload config
      bind r source-file ~/.config/tmux/tmux.conf \; display "Config reloaded"

      # Confirm before kill
      bind-key K confirm kill-window

      # Prompt navigation in copy mode
      bind-key -T copy-mode-vi [ send-keys -X previous-prompt
      bind-key -T copy-mode-vi ] send-keys -X next-prompt

      # Resize fix — sync stty rows/cols
      bind R run "echo \"stty columns $(tmux display -p \#{pane_width}); stty rows $(tmux display -p \#{pane_height})\" | tmux load-buffer - ; tmux paste-buffer"

      # --- Smart mouse scroll ---
      # Normal shell: scroll up auto-enters copy mode
      # Alternate screen (vim, less): sends arrow keys instead
      bind-key -n WheelUpPane \
          if-shell -Ft= "#{?pane_in_mode,1,#{mouse_button_flag}}" \
              "send-keys -M" \
              "if-shell -Ft= '#{alternate_on}' \
                  'send-keys Up Up Up' \
                  'copy-mode'"

      bind-key -n WheelDownPane \
          if-shell -Ft= "#{?pane_in_mode,1,#{mouse_button_flag}}" \
              "send-keys -M" \
              "send-keys Down Down Down"

      # --- Pane resize requires Ctrl+drag (prevents accidental resize while selecting text) ---
      unbind -n MouseDrag1Border
      bind -n C-MouseDrag1Border resize-pane -M

      # --- Tokyo Night status bar ---
      set -g status-style bg=default
      set -g status-left-length 90
      set -g status-right-length 90
      set -g status-justify centre

      # Left: session name in green
      set-option -gq status-left '#[fg=#1a1b26,bg=#9ece6a,bold] #S #[fg=#9ece6a,bg=default,nobold,nounderscore,noitalics]'

      # Right: empty (clean look)
      set-option -gq status-right ""

      # Inactive windows: muted
      set-option -gq window-status-format '#[fg=#565f89,bg=default] #I  #W '

      # Active window: blue highlight
      set-option -gq window-status-current-format '#[fg=#1a1b26,bg=#7aa2f7,bold] #I  #W #[fg=#7aa2f7,bg=default,nobold]'
    '';
  };
}
