## ADDED Requirements

### Requirement: Auto-attach on terminal open

When fish starts interactively, if tmux is available and the shell is
not already inside tmux (`$TMUX` is unset), fish SHALL attach to an
existing tmux session or create a new one. This SHALL execute early in
fish initialization, before other setup.

#### Scenario: New terminal attaches to existing session

- **WHEN** user opens a new terminal window with an existing detached tmux session
- **THEN** fish attaches to the existing session

#### Scenario: New terminal creates session when none exists

- **WHEN** user opens a new terminal window with no tmux sessions running
- **THEN** fish creates a new tmux session

#### Scenario: No double-nesting

- **WHEN** fish starts inside an existing tmux session
- **THEN** auto-attach does NOT execute (no nested tmux)

### Requirement: Auto-attach gated on tmux module

The auto-attach behavior SHALL only be added to fish config when
`adeci.tmux.enable` is true. Fish SHALL function normally without
tmux integration when the tmux module is disabled.

#### Scenario: tmux disabled means no auto-attach

- **WHEN** `adeci.tmux.enable` is false
- **THEN** fish starts normally without attempting tmux attach

### Requirement: Notification passthrough function

A fish function `term-notify` SHALL be available that sends OSC 777
notifications. Inside tmux, it SHALL wrap the escape sequence in DCS
passthrough (`\ePtmux;`). Outside tmux, it SHALL send the raw OSC 777
sequence.

#### Scenario: Notification inside tmux

- **WHEN** `term-notify "Build" "Complete"` is called inside tmux
- **THEN** the notification is wrapped in DCS passthrough and reaches the terminal emulator

#### Scenario: Notification outside tmux

- **WHEN** `term-notify "Build" "Complete"` is called outside tmux
- **THEN** the raw OSC 777 sequence is sent directly

### Requirement: TERM downgrade inside tmux

When running inside tmux, fish SHALL set `$TERM` to `tmux-256color` if
the terminfo is available, to prevent issues with SSH to hosts that
don't know the outer terminal's TERM value.

#### Scenario: TERM set correctly inside tmux

- **WHEN** fish starts inside a tmux session
- **THEN** `$TERM` is set to `tmux-256color`
