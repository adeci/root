## Why

The GPD Pocket 4 (praxis) has a touchscreen, but touch scrolling doesn't work in the terminal. Neither kitty (no `wl_touch` support in its GLFW fork) nor niri (forwards raw touch events, no scroll emulation) translate touch drags into scroll events. An evdev-level daemon that converts touchscreen vertical drags into virtual scroll wheel events would make touch scrolling work across the entire stack — compositor-agnostic and terminal-agnostic.

## What Changes

- Add a Python evdev daemon that reads raw touch events from the touchscreen input device and emits virtual mouse scroll wheel events via uinput
- Add a NixOS module (`adeci.touch-scroll`) that runs the daemon as a systemd service
- Enable the module on praxis (GPD Pocket 4)

## Capabilities

### New Capabilities

- `touch-scroll`: Evdev daemon that translates touchscreen vertical drag gestures into mouse scroll wheel events, with configurable sensitivity and device detection

### Modified Capabilities

_(none)_

## Impact

- New files: `modules/nixos/touch-scroll.nix`, Python script for the daemon (either inline or in `pkgs/`)
- New dependency: Python `evdev` library (available in nixpkgs)
- Requires uinput access (systemd service needs appropriate permissions)
- Only affects praxis — gated behind `adeci.touch-scroll.enable`
