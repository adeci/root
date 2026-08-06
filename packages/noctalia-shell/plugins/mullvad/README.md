# Mullvad VPN

Noctalia plugin for controlling Mullvad VPN through the `mullvad` CLI. Provides a bar widget, a panel with relay picker and quick toggles, and a settings page.

Vendored from [`noctalia-dev/noctalia-plugins`](https://github.com/noctalia-dev/noctalia-plugins/tree/ea21cb63d063075bc0acd72d8b946ce2c5eef00d/mullvad). Local changes use a theme-tinted Mullvad mole mark, hide the widget when Mullvad is unavailable, and remove unused country-flag and disconnect-confirmation settings.

`mullvad.svg` is the CC0 Mullvad mark from [Simple Icons 14.9.0](https://github.com/simple-icons/simple-icons/blob/14.9.0/icons/mullvad.svg).

## Features

- Connect / disconnect / reconnect with one click
- Status icon in the bar using the active Noctalia color scheme
- Optional city or IP next to the icon
- Search-first relay picker (country, city, or hostname) with favorites
- Quick toggles: lockdown mode, auto-connect, LAN sharing
- Advanced: multihop with entry country, IP protocol
- Account expiry warning when fewer than N days remain
- IPC handler at `plugin:mullvad` for scripting (`toggle`, `connect`, `disconnect`, `status`, `setLocation`, ...)

## Requirements

- Noctalia Shell >= 4.0.0
- `mullvad` CLI (`mullvad-cli` 2026.x or newer) and `mullvad-daemon` running
- An active Mullvad account (the plugin does not handle login; use `mullvad account login <number>`)

### Recommended: daemon-only install

This plugin replaces the official Mullvad GUI, so you only need the daemon
package (which ships the `mullvad` CLI):

- **Arch / AUR:** `paru -S mullvad-vpn-daemon` (instead of `mullvad-vpn`)
- **Debian / Ubuntu:** install only the `mullvad-daemon` package
- **Fedora:** install `mullvad-daemon` from the Mullvad repo

Then enable and start the service:

```sh
sudo systemctl enable --now mullvad-daemon
mullvad account login <YOUR_ACCOUNT_NUMBER>
```

The full `mullvad-vpn` (GUI) package will also work, but you'll have a redundant
tray icon and autostart entry.

## Settings

| Setting              | Default | Description                                   |
| -------------------- | ------- | --------------------------------------------- |
| `refreshInterval`    | 3000    | Status poll interval (ms)                     |
| `showCityName`       | false   | Show city next to the icon                    |
| `showIp`             | false   | Show current IP next to the icon              |
| `compactMode`        | false   | Icon only, no adornments                      |
| `clickAction`        | toggle  | Left-click: `toggle` or open `panel`          |
| `relayClickConnects` | true    | Clicking a relay row connects immediately     |
| `favoriteCountries`  | []      | Country codes pinned to the top of the picker |
| `expiryWarningDays`  | 7       | Threshold for the expiry banner               |

## IPC

```sh
qs -c noctalia-shell ipc call plugin:mullvad status
qs -c noctalia-shell ipc call plugin:mullvad toggle
qs -c noctalia-shell ipc call plugin:mullvad setLocation se sto
qs -c noctalia-shell ipc call plugin:mullvad setLockdown true
```

## License

MIT
