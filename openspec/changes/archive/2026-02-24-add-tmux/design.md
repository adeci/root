## Context

tmux is currently installed as a bare package in `base-tools.nix` with
zero configuration. The goal is a fully configured tmux setup modeled
after Mic92's dotfiles, adapted to fit this repo's conventions and
Tokyo Night theme.

Key existing patterns:

- Home-manager modules at `modules/home-manager/` with `adeci.<name>.enable`
- Auto-discovery of `.nix` files and directories with `default.nix`
- Fish shell configured in `modules/home-manager/fish.nix`
- Tokyo Night theme used in kitty and fish (not One Dark)
- `programs.*` home-manager options used for tool configuration

## Goals / Non-Goals

**Goals:**

- Ergonomic tmux config inspired by Mic92: `C-Space` prefix, smart
  mouse, vi copy mode, cwd-preserving splits
- tmux-thumbs plugin for hint-mode text picking with Nix hash regex
- Fish integration: auto-attach on terminal open, notification
  passthrough, TERM downgrade inside tmux
- Tokyo Night status bar (matching kitty + fish theme)
- Nix-native plugin management (no TPM)

**Non-Goals:**

- Session management automation (tmuxinator, tmux-resurrect) — keep it
  simple for a new tmux user, add later if wanted
- Remote/SSH-specific tmux config — can layer on later
- Nested tmux session handling beyond basic prefix passthrough

## Decisions

### Module structure: single `modules/home-manager/tmux.nix`

Mic92 splits config across `.tmux.conf` + `tmux-thumbs.nix` + fish
config. We'll consolidate into one home-manager module using
`programs.tmux` with `extraConfig` for settings HM doesn't have
options for (mouse scroll logic, thumbs config, status bar).

The tmux-thumbs Nix package and `run-shell` loading go in the same
module. No separate dotpkg — `programs.tmux` handles the package.

**Why not a directory?** The config is one logical unit. A directory
with `default.nix` is for multi-file setups (like kitty with extra
assets). Everything here fits in one file.

### Fish integration: additions to existing `fish.nix`

Auto-attach, `term-notify`, and TERM handling are fish concerns that
happen to involve tmux. They go in `fish.nix` behind
`config.adeci.tmux.enable` guards so they only activate when tmux is
configured.

**Alternative considered:** Put fish bits in `tmux.nix` via
`programs.fish.*`. Rejected because it scatters fish config across
modules — `fish.nix` is the single source of truth for shell behavior.

### Theme: Tokyo Night (not One Dark)

Mic92 uses One Dark for the status bar and Solarized Light for thumbs
hints. We'll use Tokyo Night colors to match kitty and fish:

| Element            | Color     | Tokyo Night token |
| ------------------ | --------- | ----------------- |
| Status bar bg      | `default` | transparent       |
| Session name bg    | `#9ece6a` | green             |
| Session name fg    | `#1a1b26` | bg dark           |
| Active window bg   | `#7aa2f7` | blue              |
| Active window fg   | `#1a1b26` | bg dark           |
| Inactive window fg | `#565f89` | comment           |
| Thumbs hint bg     | `#e0af68` | yellow            |
| Thumbs hint fg     | `#1a1b26` | bg dark           |
| Thumbs select bg   | `#7aa2f7` | blue              |

### tmux-thumbs loading: Nix profile path

Following Mic92's approach: install `tmuxPlugins.tmux-thumbs` as a
home package with `extraOutputsToInstall`, then `run-shell` from the
Nix profile path. This avoids TPM entirely.

### Remove tmux from base-tools.nix

`programs.tmux.enable = true` installs the package. Having it in
`base-tools.nix` too would be redundant. Remove it to avoid confusion
about where tmux comes from.

## Risks / Trade-offs

**[Auto-attach changes terminal workflow]** → Every new terminal
window joins tmux. This is a significant behavior change. Mitigated by:
it's what Mic92 does and what Alex wants. If it's annoying, the
auto-attach block in fish.nix is easy to remove.

**[tmux-thumbs Nix profile path is fragile]** → The `run-shell
~/.nix-profile/share/...` path depends on home-manager's profile
structure. If HM changes how it links packages, this breaks.
→ Mitigated by: this is a stable nixpkgs convention, Mic92 has used
it for years, and breakage would be obvious and easy to fix.

**[tmux not enabled everywhere by default]** → Since it's a new
`adeci.tmux.enable` option, it needs to be explicitly enabled in
machine configs or profiles. → Will enable it in the base profile
or relevant machine configs as part of implementation.
