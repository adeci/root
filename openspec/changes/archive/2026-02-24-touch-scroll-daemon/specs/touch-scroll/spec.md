## ADDED Requirements

### Requirement: Touchscreen device detection

The daemon SHALL scan `/dev/input/event*` for devices reporting `ABS_MT_POSITION_X`, `ABS_MT_POSITION_Y`, and `INPUT_PROP_DIRECT` capabilities. The daemon SHALL log and exit cleanly if no touchscreen is found.

#### Scenario: Touchscreen present

- **WHEN** the daemon starts on a machine with a touchscreen (e.g., GPD Pocket 4)
- **THEN** it identifies and opens the touchscreen evdev device

#### Scenario: No touchscreen present

- **WHEN** the daemon starts on a machine without a touchscreen
- **THEN** it logs "no touchscreen found" and exits with code 0

### Requirement: Vertical drag to scroll conversion

The daemon SHALL track single-finger touch position and emit `REL_WHEEL` events via a uinput virtual device when cumulative vertical movement exceeds a configurable threshold. One scroll tick SHALL be emitted per threshold unit of movement. The accumulator SHALL reset after each emitted tick.

#### Scenario: Finger drags upward

- **WHEN** a single finger touches the screen and drags upward past the scroll threshold
- **THEN** the daemon emits `REL_WHEEL` scroll-up events proportional to the distance dragged

#### Scenario: Finger drags downward

- **WHEN** a single finger touches the screen and drags downward past the scroll threshold
- **THEN** the daemon emits `REL_WHEEL` scroll-down events proportional to the distance dragged

#### Scenario: Movement below threshold

- **WHEN** a single finger moves less than the scroll threshold
- **THEN** no scroll events are emitted

### Requirement: Tap passthrough

The daemon SHALL NOT emit scroll events for taps (touch down followed by touch up without exceeding the scroll threshold). Normal touch behavior (tapping to focus, etc.) MUST be preserved.

#### Scenario: Quick tap on screen

- **WHEN** a finger taps the screen without significant vertical movement
- **THEN** no scroll events are emitted and the tap reaches the compositor normally

### Requirement: Non-exclusive device access

The daemon SHALL NOT grab the touchscreen device exclusively. Touch events MUST continue to flow to the compositor for normal pointer and gesture handling.

#### Scenario: Touch while daemon is running

- **WHEN** the daemon is running and the user taps or drags on the screen
- **THEN** the compositor (niri) still receives all touch events for pointer motion, window focus, and gestures

### Requirement: NixOS module integration

The daemon SHALL be controlled by an `adeci.touch-scroll.enable` option in a NixOS module. The module SHALL configure a systemd service that runs the daemon with appropriate permissions for evdev and uinput access.

#### Scenario: Module enabled on praxis

- **WHEN** `adeci.touch-scroll.enable = true` is set in a machine config
- **THEN** the systemd service is active and the daemon is running

#### Scenario: Module not enabled

- **WHEN** `adeci.touch-scroll.enable` is not set or false
- **THEN** no service or daemon is present on the system

### Requirement: Configurable scroll sensitivity

The module SHALL expose an option to configure the scroll threshold (distance in touch units per scroll tick). A sensible default SHALL be provided.

#### Scenario: Custom threshold configured

- **WHEN** the user sets a custom scroll threshold via the module option
- **THEN** the daemon uses that threshold for scroll detection

#### Scenario: Default threshold

- **WHEN** no custom threshold is configured
- **THEN** the daemon uses a reasonable default that produces natural-feeling scroll behavior
