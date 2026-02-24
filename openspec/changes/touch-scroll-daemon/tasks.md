## 1. Python Daemon Script

- [ ] 1.1 Create Python script with touchscreen auto-detection (scan evdev devices for ABS_MT_POSITION_X/Y + INPUT_PROP_DIRECT)
- [ ] 1.2 Implement uinput virtual device creation (REL_WHEEL capability)
- [ ] 1.3 Implement touch event loop: track single-finger Y position, accumulate vertical movement, emit scroll ticks at threshold
- [ ] 1.4 Handle tap passthrough (no scroll events when movement < threshold on touch up)
- [ ] 1.5 Add CLI argument for scroll threshold with sensible default
- [ ] 1.6 Add clean exit on no touchscreen found (log message, exit 0)

## 2. NixOS Module

- [ ] 2.1 Create `modules/nixos/touch-scroll.nix` with `adeci.touch-scroll.enable` option
- [ ] 2.2 Add `adeci.touch-scroll.scrollThreshold` option with default value
- [ ] 2.3 Package the Python script with evdev dependency (use pkgs.writers.writePython3Bin or similar)
- [ ] 2.4 Configure systemd service with evdev/uinput permissions and hardening (ProtectHome, NoNewPrivileges, etc.)

## 3. Machine Integration

- [ ] 3.1 Enable `adeci.touch-scroll` in `machines/praxis/configuration.nix`
- [ ] 3.2 Verify build: `nix build .#nixosConfigurations.praxis.config.system.build.toplevel`
