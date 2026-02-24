## ADDED Requirements

### Requirement: tmux-thumbs installed via Nix

The `tmuxPlugins.tmux-thumbs` package SHALL be installed via
home-manager as a home package with `extraOutputsToInstall` including
`share/tmux-plugins`. It SHALL be loaded via `run-shell` from the Nix
profile path. TPM SHALL NOT be used.

#### Scenario: Plugin loads on tmux start

- **WHEN** tmux starts a new session
- **THEN** tmux-thumbs is loaded and functional without TPM

### Requirement: Thumbs activation keybinding

tmux-thumbs SHALL be activated with `prefix f`.

#### Scenario: Activate hint mode

- **WHEN** user presses `prefix f`
- **THEN** tmux-thumbs overlays hint labels on matching text in the pane

### Requirement: Lowercase select opens, uppercase pastes

Lowercase selection (`@thumbs-command`) SHALL attempt to open the
matched text with `xdg-open` (Linux) or `open` (macOS). Uppercase
selection (`@thumbs-upcase-command`) SHALL copy the match to the tmux
paste buffer and paste it into the active pane.

#### Scenario: Open a URL with lowercase hint

- **WHEN** user activates thumbs and types a lowercase hint for a URL
- **THEN** the URL opens in the default browser via `xdg-open`

#### Scenario: Paste a hash with uppercase hint

- **WHEN** user activates thumbs and types an uppercase hint for a hash
- **THEN** the hash text is pasted into the current pane at the cursor

### Requirement: Custom Nix hash regex

tmux-thumbs SHALL include a custom regex matching:

- SRI hashes: `sha256-` followed by 44 base64 characters
- Git commit hashes: 7-40 hex characters
- Nix store path hashes: 52 base32 characters

#### Scenario: Match SRI hash in build output

- **WHEN** `nix build` output contains `sha256-abc123...` (44 chars)
- **THEN** tmux-thumbs shows a hint label on the hash

#### Scenario: Match git commit hash

- **WHEN** `git log --oneline` output shows short commit hashes
- **THEN** tmux-thumbs shows hint labels on the hashes

### Requirement: Thumbs display options

Contrast mode SHALL be enabled (`@thumbs-contrast 1`). Unique matching
SHALL be enabled (`@thumbs-unique 1`). Reverse hint assignment SHALL
be enabled (`@thumbs-reverse enabled`) so bottom-of-screen text gets
the easiest hint keys.

#### Scenario: Bottom text gets easy hints

- **WHEN** user activates thumbs with matching text at top and bottom
- **THEN** the bottom (most recent) matches get shorter/easier hint keys

### Requirement: Tokyo Night thumbs colors

Thumbs hint colors SHALL use Tokyo Night palette: yellow (`#e0af68`)
background for hints, blue (`#7aa2f7`) for selection, dark (`#1a1b26`)
for foreground text.

#### Scenario: Hint colors match theme

- **WHEN** user activates tmux-thumbs
- **THEN** hint labels display in Tokyo Night yellow with dark text
