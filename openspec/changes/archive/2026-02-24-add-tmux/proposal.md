## Why

tmux is installed but completely unconfigured — it's just a raw package in
`base-tools.nix`. Adding a proper configuration turns it into a real
workflow tool: ergonomic keybindings, smart mouse behavior, hint-mode
text grabbing (especially useful for Nix hashes), and a clean status bar.
Modeled after Mic92's battle-tested dotfiles setup.

## What Changes

- Create a dedicated `adeci.tmux.enable` home-manager module with full
  tmux configuration (prefix, keybindings, mouse, copy mode, appearance)
- Install and configure tmux-thumbs plugin via nixpkgs (no TPM) for
  hint-mode text selection with custom Nix hash regex
- Add fish shell integration: auto-attach on terminal open, notification
  passthrough function
- Remove bare `tmux` package from `base-tools.nix` (the new module
  manages the package via `programs.tmux`)

## Capabilities

### New Capabilities

- `tmux-core`: Base tmux configuration — prefix key, keybindings, mouse
  behavior, copy mode, terminal features, environment forwarding
- `tmux-thumbs`: tmux-thumbs plugin setup with hint-mode picking, Nix
  hash regex, and open/paste actions
- `tmux-fish-integration`: Fish shell auto-attach, notification
  passthrough, and TERM handling inside tmux
- `tmux-appearance`: Status bar theme and visual configuration (One Dark
  powerline style)

### Modified Capabilities

_(none — no existing specs)_

## Impact

- `modules/home-manager/base-tools.nix` — remove `tmux` from package list
- `modules/home-manager/tmux/` — new module directory (auto-discovered)
- `modules/home-manager/fish.nix` — additions for tmux integration
  (auto-attach, term-notify function, TERM handling)
- Machines that enable `adeci.tmux` get the full configured experience
- Fish shell behavior changes: new terminals will auto-attach to tmux
