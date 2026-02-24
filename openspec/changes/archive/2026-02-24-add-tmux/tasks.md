## 1. Create tmux home-manager module

- [x] 1.1 Create `modules/home-manager/tmux.nix` with `adeci.tmux.enable` option
- [x] 1.2 Configure `programs.tmux` — enable, set prefix to `C-Space`, base-index 1, escape-time 0, history-limit 50000, mouse on, vi copy mode, emacs status keys
- [x] 1.3 Add terminal capabilities — `tmux-256color`, true color override, hyperlinks, passthrough, focus-events, set-clipboard, set-titles
- [x] 1.4 Add keybindings — cwd-preserving splits/new-window, confirm kill window/server, prompt navigation in copy mode
- [x] 1.5 Add smart mouse scroll logic via `extraConfig` (auto-enter copy-mode on scroll up in normal shell, send arrow keys in alternate screen)
- [x] 1.6 Add environment forwarding (`update-environment` with SSH, display, TERM vars)
- [x] 1.7 Add remaining options — renumber-windows, aggressive-resize, visual-activity, display-time, status-interval

## 2. tmux-thumbs plugin

- [x] 2.1 Add `tmuxPlugins.tmux-thumbs` to home packages with `extraOutputsToInstall`
- [x] 2.2 Configure thumbs in `extraConfig` — key binding (`f`), open/paste commands, contrast, unique, reverse
- [x] 2.3 Add Nix hash custom regex (`sha256-...`, git hashes, Nix store hashes)
- [x] 2.4 Set Tokyo Night hint colors (yellow hint bg, blue select bg, dark fg)
- [x] 2.5 Add `run-shell` line to load thumbs from Nix profile path

## 3. Status bar appearance

- [x] 3.1 Add Tokyo Night powerline status bar in `extraConfig` — transparent bg, green session name, blue active window, muted inactive windows
- [x] 3.2 Configure window format with index and name (`#I`, `#W`), session format (`#S`), centered justify

## 4. Fish shell integration

- [x] 4.1 Add auto-attach block to `fish.nix` `interactiveShellInit` — guarded by `config.adeci.tmux.enable`, runs early (before other init), attaches or creates session
- [x] 4.2 Add `term-notify` fish function — OSC 777 with DCS passthrough when inside tmux
- [x] 4.3 Add TERM downgrade block — set `tmux-256color` when inside tmux if terminfo available

## 5. Cleanup and wiring

- [x] 5.1 Remove `tmux` from `base-tools.nix` package list
- [x] 5.2 Enable `adeci.tmux` in relevant machine configs or profiles
- [x] 5.3 Run `nix fmt` and verify build with `nix build .#nixosConfigurations.<machine>.config.system.build.toplevel`
