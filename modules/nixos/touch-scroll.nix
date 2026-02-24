{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.adeci.touch-scroll;

  daemon =
    pkgs.writers.writePython3Bin "touch-scroll-daemon"
      {
        libraries = [ pkgs.python3Packages.evdev ];
      }
      ''
        import sys
        import argparse
        import evdev
        from evdev import ecodes, UInput


        def find_touchscreen():
            """Find first touchscreen (ABS_MT_POSITION + INPUT_PROP_DIRECT)."""
            for path in evdev.list_devices():
                try:
                    dev = evdev.InputDevice(path)
                except OSError:
                    continue
                caps = dev.capabilities()
                abs_caps = caps.get(ecodes.EV_ABS, [])
                abs_codes = {c[0] if isinstance(c, tuple) else c for c in abs_caps}
                if (
                    ecodes.ABS_MT_POSITION_X not in abs_codes
                    or ecodes.ABS_MT_POSITION_Y not in abs_codes
                ):
                    dev.close()
                    continue
                if ecodes.INPUT_PROP_DIRECT not in dev.input_props():
                    dev.close()
                    continue
                return dev
            return None


        def main():
            parser = argparse.ArgumentParser(description="Touch scroll daemon")
            parser.add_argument("--threshold", type=int, default=50)
            args = parser.parse_args()

            dev = find_touchscreen()
            if dev is None:
                print("No touchscreen found", flush=True)
                sys.exit(0)

            print(
                "Using touchscreen: " + dev.name + " (" + dev.path + ")",
                flush=True,
            )

            ui = UInput(
                {ecodes.EV_REL: [ecodes.REL_WHEEL]},
                name="touch-scroll-daemon",
            )

            threshold = args.threshold
            current_slot = 0
            slots = {}
            slot_y = {}
            accumulator = 0

            try:
                for event in dev.read_loop():
                    if event.type != ecodes.EV_ABS:
                        continue

                    if event.code == ecodes.ABS_MT_SLOT:
                        current_slot = event.value

                    elif event.code == ecodes.ABS_MT_TRACKING_ID:
                        if event.value == -1:
                            slots.pop(current_slot, None)
                            slot_y.pop(current_slot, None)
                        else:
                            slots[current_slot] = event.value
                        accumulator = 0

                    elif event.code == ecodes.ABS_MT_POSITION_Y:
                        old_y = slot_y.get(current_slot)
                        slot_y[current_slot] = event.value
                        if (
                            len(slots) == 1
                            and current_slot in slots
                            and old_y is not None
                        ):
                            delta = event.value - old_y
                            accumulator += delta
                            while accumulator >= threshold:
                                ui.write(ecodes.EV_REL, ecodes.REL_WHEEL, -1)
                                ui.syn()
                                accumulator -= threshold
                            while accumulator <= -threshold:
                                ui.write(ecodes.EV_REL, ecodes.REL_WHEEL, 1)
                                ui.syn()
                                accumulator += threshold
            except KeyboardInterrupt:
                pass
            finally:
                ui.close()
                dev.close()


        main()
      '';
in
{
  options.adeci.touch-scroll = {
    enable = lib.mkEnableOption "touchscreen vertical drag to scroll wheel daemon";
    scrollThreshold = lib.mkOption {
      type = lib.types.int;
      default = 50;
      description = "Vertical distance in touch units per scroll tick.";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.kernelModules = [ "uinput" ];

    services.udev.extraRules = ''
      KERNEL=="uinput", MODE="0660", GROUP="input"
    '';

    systemd.services.touch-scroll = {
      description = "Touchscreen vertical drag to scroll wheel daemon";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-udev-settle.service" ];
      serviceConfig = {
        ExecStart = "${daemon}/bin/touch-scroll-daemon --threshold ${toString cfg.scrollThreshold}";
        Restart = "on-failure";
        RestartSec = 5;
        ProtectHome = true;
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        PrivateTmp = true;
      };
    };
  };
}
