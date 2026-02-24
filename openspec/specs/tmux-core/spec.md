## ADDED Requirements

### Requirement: Prefix key is C-Space

The tmux prefix key SHALL be `C-Space`. The default `C-b` binding SHALL
be unbound. `C-Space` SHALL send the prefix through for nested sessions.

#### Scenario: Prefix key works

- **WHEN** user presses `C-Space` followed by a tmux command key
- **THEN** tmux executes the command

### Requirement: Vi copy mode with emacs command prompt

Copy mode SHALL use vi keybindings (`mode-keys vi`). The tmux command
prompt SHALL use emacs keybindings (`status-keys emacs`).

#### Scenario: Copy mode navigation

- **WHEN** user enters copy mode
- **THEN** vi motion keys (hjkl, /, ?, etc.) navigate the scrollback

### Requirement: Smart mouse scroll behavior

Mouse SHALL be enabled. Scroll wheel behavior SHALL be context-aware:

- In normal mode: scroll up enters copy-mode automatically
- In alternate screen (vim, less): sends Up/Down arrow keys instead
- Already in copy/scroll mode: passes scroll through normally

#### Scenario: Scroll up in normal shell

- **WHEN** user scrolls up in a pane showing a normal shell prompt
- **THEN** tmux enters copy-mode and scrolls up

#### Scenario: Scroll up in vim

- **WHEN** user scrolls up in a pane running vim or another alternate-screen app
- **THEN** tmux sends `Up Up Up` key presses to the application

### Requirement: Splits and new windows preserve working directory

The split-vertical (`"`), split-horizontal (`%`), and new-window (`c`)
bindings SHALL open in `#{pane_current_path}`.

#### Scenario: Split preserves directory

- **WHEN** user is in `/home/alex/git/root` and presses `prefix "`
- **THEN** the new split pane opens in `/home/alex/git/root`

### Requirement: Window numbering starts at 1 with auto-renumber

Base index SHALL be 1. Windows SHALL auto-renumber on close
(`renumber-windows on`).

#### Scenario: Windows renumber after close

- **WHEN** user has windows 1, 2, 3 and closes window 2
- **THEN** remaining windows are numbered 1 and 2

### Requirement: Zero escape time

Escape time SHALL be 0 to eliminate mode-switching delay in vim.

#### Scenario: No vim escape delay

- **WHEN** user presses Escape in vim running inside tmux
- **THEN** vim responds immediately with no perceptible delay

### Requirement: Large scrollback buffer

History limit SHALL be 50000 lines.

#### Scenario: Scrollback available

- **WHEN** user has run many commands producing extensive output
- **THEN** up to 50000 lines of scrollback are available in copy mode

### Requirement: Terminal capabilities

Default terminal SHALL be `tmux-256color`. True color (24-bit) SHALL be
enabled via terminal overrides. OSC-8 hyperlinks SHALL be enabled.
OSC passthrough SHALL be allowed.

#### Scenario: True color rendering

- **WHEN** an application outputs 24-bit RGB color sequences
- **THEN** colors render correctly without degradation

### Requirement: Environment forwarding on reattach

The `update-environment` setting SHALL include `DISPLAY`,
`SSH_AUTH_SOCK`, `SSH_CONNECTION`, `SSH_TTY`, `TERM`, and other
relevant SSH/display variables.

#### Scenario: SSH agent works after reattach

- **WHEN** user detaches and reattaches to a tmux session
- **THEN** `SSH_AUTH_SOCK` is updated to the current value

### Requirement: Confirm before kill

`prefix k` SHALL confirm before killing a window. `prefix K` SHALL
confirm before killing the server.

#### Scenario: Kill window confirmation

- **WHEN** user presses `prefix k`
- **THEN** tmux prompts for confirmation before killing the window

### Requirement: Prompt navigation in copy mode

In copy-mode-vi, `[` SHALL jump to the previous shell prompt and `]`
SHALL jump to the next shell prompt.

#### Scenario: Jump to previous prompt

- **WHEN** user is in copy mode and presses `[`
- **THEN** cursor jumps to the previous shell prompt marker

### Requirement: Clipboard sync

`set-clipboard` SHALL be `on` to sync the tmux buffer with the
terminal clipboard.

#### Scenario: Copy syncs to system clipboard

- **WHEN** user copies text in tmux copy mode
- **THEN** the text is available in the system clipboard
