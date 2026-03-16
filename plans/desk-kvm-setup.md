# Desk KVM Setup Plan

Central 32" monitor with machines mounted around it in an iron-man
command center layout.

## KVM

**Level1Techs HDMI 2.1 KVM w/EDID & Serial Control — Single Monitor,
Four Computer ($575)**

- Only Level1Techs KVM with built-in EDID emulation (no monitor
  re-handshake jank when switching)
- Their DP 1.4 KVMs do NOT have EDID despite the marketing around
  their "EDID engine" — that's HDCP only
- Currently sold out — signed up for restock notification
- Store: https://www.store.level1techs.com/products/p/hdmi-21-kvm-wedid-serial-control-single-monitor-four-computer
- Restock thread: https://forum.level1techs.com/t/l1-store-kvm-restocking/221181

## Machines

| Slot | Machine | What it is                   | Video to KVM        | USB to KVM           |
| ---- | ------- | ---------------------------- | ------------------- | -------------------- |
| 1    | Praxis  | GPD Pocket 4, main dev       | Native HDMI 2.1     | USB-C 3.2 Gen2       |
| 2    | Malum   | MacBook Pro M4, Shopify work | Native HDMI         | Thunderbolt/USB-C    |
| 3    | Windows | Gaming laptop                | Native HDMI         | USB-C (or USB-A)     |
| 4    | TBD     | Framework 13 (future)        | HDMI expansion card | USB-C expansion card |

Aegis (ThinkPad X220, coreboot security machine) stays off the KVM —
it's a standalone device that doesn't need to be part of the switching
setup.

## Physical Layout

```
        [Malum]          [FW13 future]
           \                /
            \              /
     [Win Gaming]  [32" Monitor]  [Aegis standalone]
                    [Praxis]
```

- Praxis sits under/in front of the monitor (tiny form factor)
- Malum + Windows gaming on swing mounts flanking the sides
- Future FW13 on the opposite side
- Laptops open for a 5-screen look (4 laptop screens + center monitor)

## Cables Needed

| Cable                       | Qty | Notes                                                               |
| --------------------------- | --- | ------------------------------------------------------------------- |
| HDMI 2.1 (48Gbps certified) | 5   | 1 per device + 1 KVM → monitor. Must be Ultra High Speed certified. |
| USB-C to USB-C (3.2 Gen 2)  | 3-4 | 1 per device for KVM USB data.                                      |
| USB-C to USB-A              | 0-1 | Only if Windows gaming laptop lacks USB-C.                          |

No adapters needed — all devices have native HDMI out (MacBook M4
included). No docks needed for the KVM setup itself.

## Charging (independent of KVM)

- **Praxis**: USB4 port (not used by KVM)
- **Malum**: MagSafe
- **Windows gaming**: Barrel connector
- **FW13**: USB-C (separate expansion card slot)

## Touch ID (Malum)

macOS Touch ID requires the Secure Enclave — no third-party USB
fingerprint reader works. Options:

- Position Malum within arm's reach on a swing mount to use the
  built-in Touch ID when needed
- Apple Magic Keyboard with Touch ID ($200) if that's not practical

The `mru-spaces = false` setting is already in the darwin config
(`modules/darwin/base.nix`) which helps with space rearrangement on
monitor connect/disconnect.

## UGreen Dock

Not needed for the KVM setup. Keep it only if ethernet or extra USB
ports are needed on a specific machine at the desk. Most likely
candidate would be Praxis since it has the fewest ports.
