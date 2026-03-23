# Roster — User Management for Clan

A Clan service module that provides centralized, position-based user management across your fleet, with support for both NixOS and Darwin.

## Why Roster?

**Single source of truth** for user access. Define users once, then declare who has access to each machine.

## Core Concepts

### Positions

Built-in permission levels that control user privileges:

| Position  | Sudo | Password Gen | Home Dir | Type   | Purpose                       |
| --------- | ---- | ------------ | -------- | ------ | ----------------------------- |
| `owner`   | Yes  | Yes          | Yes      | Normal | Primary machine administrator |
| `admin`   | Yes  | Yes          | Yes      | Normal | Secondary administrators      |
| `basic`   | No   | Yes          | Yes      | Normal | Regular users                 |
| `service` | No   | No           | No       | System | Service accounts              |

### Configuration

```nix
{
  roster = {
    module = {
      name = "@adeci/roster";
      input = "self";
    };
    roles.default = {
      tags.all = { };
      settings = {
        # Optional: define custom positions
        positions = {
          contractor = {
            sudoAccess = false;
            generatePassword = true;
            homeDirectory = true;
            isSystemUser = false;
          };
        };

        # Define users once
        users = {
          alice = {
            uid = 1001;
            defaultPosition = "owner";
            description = "Alice Smith";
            groups = [ "networkmanager" "docker" ];
            sshAuthorizedKeys = [ "ssh-ed25519 AAAA..." ];
            defaultShell = "fish";
          };
        };

        # Assign users to machines
        machines = {
          prod-server = {
            users = {
              alice = { };  # uses all defaults
            };
          };
          dev-machine = {
            users = {
              alice = {
                position = "admin";         # override position
                extraGroups = [ "libvirtd" ]; # add groups
                shell = "bash";              # override shell
              };
            };
          };
        };
      };
    };
  };
}
```

## Features

### Dual Platform Support

| Concern        | NixOS                         | Darwin          |
| -------------- | ----------------------------- | --------------- |
| Home directory | `/home/<user>`                | `/Users/<user>` |
| User type      | `isNormalUser`/`isSystemUser` | Not set         |
| Password gen   | Enabled via `clan.core.vars`  | Skipped         |
| `mutableUsers` | `false`                       | Not set         |
| Root SSH keys  | Collected from sudo users     | Skipped         |

### Machine-Specific Overrides

Override any user property per machine:

- `position` — different role on this machine
- `uid` — different UID (rare, but supported)
- `groups` — replace default groups entirely
- `extraGroups` — add groups to defaults
- `shell` — different shell on this machine
- `sshAuthorizedKeys` — replace SSH keys
- `extraSshAuthorizedKeys` — add SSH keys to defaults

### Shell Resolution

Shells are specified as string names (e.g., `"fish"`, `"zsh"`) and resolved to `pkgs.${name}` in the generated module. This keeps the interface JSON-serializable.

### Automatic Features

- **Password Generation**: based on position's `generatePassword` flag (NixOS only)
- **Root SSH Access**: users with `sudoAccess` get SSH keys added to root (NixOS only)
- **Immutable Users**: sets `users.mutableUsers = false` (NixOS only)
- **Primary User**: the first `owner`-positioned user sets `adeci.primaryUser`

### Configuration Precedence

1. Machine-specific overrides
2. User defaults
3. Position defaults
4. Fallback defaults (`sudoAccess=false`, `generatePassword=false`, `homeDirectory=true`, `isSystemUser=false`)

### Per-User Flag Overrides

Individual flags can be overridden without changing positions:

```nix
# Per-user (applies everywhere)
users.alice = {
  uid = 1001;
  defaultPosition = "basic";
  sudoAccess = true;  # grant sudo despite "basic" position
};

# Per-machine (applies to specific machine)
machines.prod-server = {
  users.alice = {
    generatePassword = false;  # don't generate password here
  };
};
```

## What Roster Does NOT Do

Roster is purely system-level user management. It does not handle:

- **Home-manager configuration** — use per-machine `home.nix` files with `home-manager.users.<name> = import ./home.nix`
- **Dotfile management** — use home-manager modules or profiles
- **Application configuration** — handled by NixOS/Darwin modules
