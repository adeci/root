## 1. Python Daemon Script

- [x] 1.1 Create Python script with touchscreen auto-detection (scan evdev devices for ABS_MT_POSITION_X/Y + INPUT_PROP_DIRECT)
- [x] 1.2 Implement uinput virtual device creation (REL_WHEEL capability)
- [x] 1.3 Implement touch event loop: track single-finger Y position, accumulate vertical movement, emit scroll ticks at threshold
- [x] 1.4 Handle tap passthrough (no scroll events when movement < threshold on touch up)
- [x] 1.5 Add CLI argument for scroll threshold with sensible default
- [x] 1.6 Add clean exit on no touchscreen found (log message, exit 0)

## 2. NixOS Module

- [x] 2.1 Create `modules/nixos/touch-scroll.nix` with `adeci.touch-scroll.enable` option
- [x] 2.2 Add `adeci.touch-scroll.scrollThreshold` option with default value
- [x] 2.3 Package the Python script with evdev dependency (use pkgs.writers.writePython3Bin or similar)
- [x] 2.4 Configure systemd service with evdev/uinput permissions and hardening (ProtectHome, NoNewPrivileges, etc.)

## 3. Machine Integration

- [x] 3.1 Enable `adeci.touch-scroll` in `machines/praxis/configuration.nix`
- [x] 3.2 Verify build: `nix build .#nixosConfigurations.praxis.config.system.build.toplevel`
