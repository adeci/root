## ADDED Requirements

### Requirement: Tokyo Night status bar theme

The tmux status bar SHALL use Tokyo Night colors matching the kitty and
fish theme configuration. The status bar background SHALL be transparent
(`default`).

#### Scenario: Status bar renders in Tokyo Night colors

- **WHEN** tmux is running
- **THEN** the status bar displays with Tokyo Night color palette and transparent background

### Requirement: Status bar layout

The session name SHALL display on the left in green (`#9ece6a`) with
dark foreground (`#1a1b26`). Windows SHALL be centered
(`status-justify centre`). The active window SHALL be highlighted in
blue (`#7aa2f7`) with dark foreground. Inactive windows SHALL use
muted comment color (`#565f89`).

#### Scenario: Active window is visually distinct

- **WHEN** user has multiple windows open
- **THEN** the active window tab is blue and inactive tabs are muted gray

### Requirement: Window titles show index and name

Each window in the status bar SHALL display its index (`#I`) and name
(`#W`). The session name SHALL display as `#S`.

#### Scenario: Window format

- **WHEN** user has window 1 named "fish" and window 2 named "nvim"
- **THEN** status bar shows `1  fish` and `2  nvim` with appropriate styling

### Requirement: Terminal title set to hostname

tmux SHALL set the terminal title to the hostname (`#H`) via
`set-titles on` and `set-titles-string "#H"`.

#### Scenario: Terminal title reflects host

- **WHEN** tmux is running on host "eve"
- **THEN** the terminal emulator title bar shows "eve"
