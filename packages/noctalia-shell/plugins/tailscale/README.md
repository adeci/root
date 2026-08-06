# Tailscale Plugin

A Tailscale status plugin for Noctalia that shows connection and peer status and sends files via Taildrop.

Vendored from [`noctalia-dev/noctalia-plugins`](https://github.com/noctalia-dev/noctalia-plugins/tree/ea21cb63d063075bc0acd72d8b946ce2c5eef00d/tailscale). Local changes omit optional translations, an unused SVG asset, development mock data, and Taildrop receiving. The peer list uses aligned online, external-tailnet, exit-node, and subnet-route indicators with explanatory tooltips, and the widget draws its mark in `TailscaleIcon.qml`.

> **Disclaimer:** This is a community-created plugin built on the Tailscale CLI. It is not affiliated with, endorsed by, or officially connected to Tailscale Inc.

## Features

- **Status Indicator**: Shows whether Tailscale is connected or disconnected with a visual indicator
- **IP Address Display**: Shows your current Tailscale IP address when connected
- **Peer Count**: Displays the number of connected devices in your tailnet
- **Read-only Local Status**: Connection and daemon configuration remain under command-line or system configuration control
- **Peer Context Menu**: Right-click a peer in the panel to copy its IP or FQDN, launch SSH/ping actions, or send a file via Taildrop
- **Node Search**: Optionally filter the panel node list by hostname, DNS name, Tailscale name, IP address, or OS
- **Peer Status**: Green online dots and owner-labelled indicators for machines shared from another tailnet
- **Manual Refresh**: Refresh status directly from the panel header
- **Exit Node Status**: Shows the active exit node and nodes advertising exit-node or subnet-route capabilities
- **Admin Console**: Opens the Tailscale web administration console
- **Context Menu**: Right-click the bar widget to open plugin settings
- **Configurable Refresh**: Customize how often the plugin checks Tailscale status
- **Compact Mode**: Option to show only the icon for a minimal display

## Requirements

- Tailscale must be installed on your system
- Tailscale must be set up and authenticated

## Taildrop

Right-click any online peer in the panel and choose **Send File**. Select one or more files and the plugin sends them with `tailscale file cp`. Disable Taildrop in plugin settings to remove the send action.

## Settings

| Setting                | Default     | Description                                                   |
| ---------------------- | ----------- | ------------------------------------------------------------- |
| `refreshInterval`      | `5000` ms   | How often to check Tailscale status (1000–60000 ms)           |
| `compactMode`          | `false`     | Show only the icon in the menu bar                            |
| `showIpAddress`        | `true`      | Display your Tailscale IP address                             |
| `showPeerCount`        | `true`      | Display the number of connected peers                         |
| `hideDisconnected`     | `false`     | Hide disconnected peers from the panel list                   |
| `hideMullvadExitNodes` | `true`      | Hide Mullvad VPN exit nodes from the peer list                |
| `showSearchBar`        | `false`     | Show a search field above the panel node list                 |
| `terminalCommand`      | `""`        | Terminal for SSH/ping (e.g. `ghostty`, `alacritty`)           |
| `sshUsername`          | `""`        | Username for SSH connections (leave empty for system default) |
| `pingCount`            | `5`         | Number of pings to send when pinging a peer                   |
| `defaultPeerAction`    | `"copy-ip"` | Action when clicking a peer: `copy-ip`, `ssh`, or `ping`      |
| `taildropEnabled`      | `true`      | Show the Taildrop send action                                 |

## IPC Commands

You can control the Tailscale plugin via the command line using the Noctalia IPC interface.

### General Usage

```bash
qs -c noctalia-shell ipc call plugin:tailscale <command>
```

### Available Commands

| Command       | Description                    | Example                                                      |
| ------------- | ------------------------------ | ------------------------------------------------------------ |
| `togglePanel` | Toggle Tailscale panel         | `qs -c noctalia-shell ipc call plugin:tailscale togglePanel` |
| `status`      | Get current Tailscale status   | `qs -c noctalia-shell ipc call plugin:tailscale status`      |
| `refresh`     | Force refresh Tailscale status | `qs -c noctalia-shell ipc call plugin:tailscale refresh`     |

## Usage

1. **Click** the icon to open the Tailscale panel
2. **Right-click the bar widget** to open plugin settings
3. **Right-click a peer** in the panel to copy its IP/FQDN, SSH, ping, or send a file
4. **Search nodes**: if enabled in settings, type in the panel search box to filter by hostname, DNS name, Tailscale name, IP address, or OS

## Troubleshooting

### "Not installed" message

If you see "Tailscale not installed" in the context menu, make sure Tailscale is installed and accessible in your PATH.

### Status not updating

If the status doesn't update automatically, try:

1. Increasing the refresh interval in settings
2. Using the refresh button in the panel header
3. Checking that Tailscale is running properly on your system

Connect, disconnect, login, account switching, and exit-node selection are intentionally left to the `tailscale` command or declarative system configuration.
