## Context

The GPD Pocket 4 (praxis) has a touchscreen but no layer in the stack — niri, kitty, or tmux — translates touch drags into scroll events. Kitty's GLFW fork doesn't implement `wl_touch`, and niri forwards raw touch events without scroll emulation. We need a daemon that bridges this gap at the evdev level, below the compositor.

## Goals / Non-Goals

**Goals:**

- Vertical touch drag on the touchscreen produces scroll wheel events that work in kitty + tmux
- Runs as a systemd service, auto-detecting the touchscreen device
- Configurable sensitivity and scroll direction
- Clean NixOS module gated behind `adeci.touch-scroll.enable`

**Non-Goals:**

- Horizontal scroll support (not needed for terminal scrolling)
- Kinetic/inertial scrolling (nice to have later, not MVP)
- Multi-finger gesture support (niri PR #3180 covers that)
- Supporting non-touchscreen input devices
- Working on X11 (we're Wayland-only)

## Decisions

### 1. Python + evdev library for the daemon

**Choice**: Python script using the `evdev` package for reading touch events and `uinput` for emitting scroll events.

**Alternatives considered**:
- **C/Rust binary**: More performant but overkill — touch events are low-frequency, and Python `evdev` is well-tested on NixOS.
- **libinput quirks**: Can't remap touchscreen drag → scroll; quirks are for device identification, not event transformation.
- **Input-remapper**: Heavy GUI tool, hard to configure declaratively in NixOS.

**Rationale**: Python + evdev is the simplest approach that's still reliable. Easy to iterate on, debug, and tune sensitivity.

### 2. Auto-detect touchscreen via evdev capabilities

**Choice**: Scan `/dev/input/event*` devices for ones that report `ABS_MT_POSITION_X` and `ABS_MT_POSITION_Y` (multi-touch absolute axes) and have `INPUT_PROP_DIRECT` (direct touch, not touchpad).

**Rationale**: This reliably identifies touchscreens vs touchpads. The GPD Pocket 4's touchscreen will report these. Falls back gracefully if no touchscreen is found.

### 3. Scroll event emission via uinput virtual device

**Choice**: Create a virtual input device via uinput that emits `REL_WHEEL` events. These flow through libinput → niri → kitty as normal scroll events.

**Rationale**: This is the standard Linux mechanism for virtual input. The events are indistinguishable from a real mouse wheel to all consumers.

### 4. Threshold-based scroll detection

**Choice**: Track finger Y position. When cumulative vertical movement exceeds a configurable threshold (in touch units), emit one scroll tick and reset the accumulator.

**Rationale**: Simple and predictable. The threshold controls sensitivity — smaller = more sensitive. Can be tuned per-device since touch coordinate ranges vary.

### 5. Single-finger only, with tap passthrough

**Choice**: Only convert single-finger vertical drags to scroll. Taps (touch down + up without significant movement) are ignored so compositor/app tap handling still works.

**Rationale**: We don't want to break normal touch interactions (tapping to focus windows, etc.). Only sustained vertical drags should scroll.

### 6. NixOS module with systemd service

**Choice**: `modules/nixos/touch-scroll.nix` with `adeci.touch-scroll.enable` option. The Python script lives inline in the module (it's small enough). Systemd service runs as root (needed for evdev/uinput access) with hardened security options.

**Rationale**: Follows the existing module pattern. Root is required for `/dev/input/*` and `/dev/uinput` access, but we can use systemd sandboxing to limit the blast radius.

## Risks / Trade-offs

- **[Sensitivity tuning]** → The scroll threshold will need on-device testing. We'll expose it as a module option with a sensible default, but Alex will need to tune it on praxis.
- **[Interferes with normal touch]** → The daemon reads touch events but doesn't grab them exclusively, so the compositor still gets them. Risk: a touch drag might both scroll AND move the niri pointer. Mitigation: niri's pointer motion from touch is harmless when scrolling in a focused terminal.
- **[Device hotplug]** → If the touchscreen disconnects/reconnects (unlikely on a built-in screen), the daemon won't re-detect. Mitigation: systemd `Restart=on-failure` handles this.
- **[Root access]** → Service needs root for evdev/uinput. Mitigation: systemd hardening (ProtectHome, NoNewPrivileges, etc.).
