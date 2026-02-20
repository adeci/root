---
name: screenshot-cli
description: Take screenshots of the screen. Use when needing to see the display or debug graphical issues.
---

# Screenshot CLI

Cross-platform screenshot tool. Uses `spectacle` (KDE), `grim` (Wayland),
or `screencapture` (macOS).

## Install

```bash
nix run github:Mic92/mics-skills#screenshot-cli -- --help
```

## Usage

```bash
screenshot-cli                     # Fullscreen (default)
screenshot-cli -w                  # Focused window
screenshot-cli -r                  # Interactive region selection
screenshot-cli -d 3                # Delay 3s before capture
screenshot-cli /tmp/shot.png       # Custom output path
```

Prints the output file path on stdout. View the result with the `read` tool:

```bash
path=$(screenshot-cli)
# Then use read tool on $path
```
