# Roster - Hierarchical User Management for Clan

A Clan service module that provides centralized, position-based user management across your fleet, with first-class support for both NixOS and Darwin.

## Why Roster?

**Single source of truth** for user access. Define users once, then simply declare who has access to each machine (with any tweaks you like).

## Key Differences from Clan Built-in Modules

| Aspect               | clan-core/users       | clan-core/admin       | Roster                             |
| -------------------- | --------------------- | --------------------- | ---------------------------------- |
| **User Definition**  | Per-service instance  | Per-service instance  | Once globally                      |
| **Machine View**     | Hunt through services | Hunt through services | `machines.<name>.users`            |
| **Permission Model** | Groups only           | Admin only            | Position hierarchy                 |
| **UID Management**   | Per-instance          | Per-instance          | Consistent across fleet            |
| **Override Pattern** | Redefine entirely     | Redefine entirely     | Inherit + override specific fields |
| **Platform Support** | NixOS only            | NixOS only            | NixOS + Darwin                     |

## Core Concepts

### Positions

Built-in permission levels that control user privileges:

| Position  | Sudo | Password Gen | Home Dir | Type   | Purpose                       |
| --------- | ---- | ------------ | -------- | ------ | ----------------------------- |
| `owner`   | Yes  | Yes          | Yes      | Normal | Primary machine administrator |
| `admin`   | Yes  | Yes          | Yes      | Normal | Secondary administrators      |
| `basic`   | No   | Yes          | Yes      | Normal | Regular users                 |
| `service` | No   | No           | No       | System | Service accounts              |

### Configuration Structure

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
        # Optional: Define custom positions
        positions = {
          contractor = {
            sudoAccess = false;
            generatePassword = true;
            homeDirectory = true;
            isSystemUser = false;
          };
        };

        # Step 1: Define users ONCE (all JSON-serializable)
        users = {
          alice = {
            uid = 1001;
            defaultPosition = "owner";
            description = "Alice Smith";
            groups = ["networkmanager" "docker"];
            sshAuthorizedKeys = ["ssh-ed25519 AAAA..."];
            defaultShell = "fish";  # Resolved to pkgs.fish in the generated module
          };
        };

        # Step 2: Assign users to machines
        machines = {
          prod-server = {
            users = {
              alice = { };  # Uses all defaults from user definition
            };
          };

          dev-machine = {
            users = {
              alice = {
                position = "admin";  # Override position for this machine
                extraGroups = ["libvirtd"];  # Add extra groups
                shell = "bash";  # Override shell
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

Roster generates both `nixosModule` and `darwinModule`, handling platform differences automatically:

| Concern        | NixOS                         | Darwin          |
| -------------- | ----------------------------- | --------------- |
| Home directory | `/home/<user>`                | `/Users/<user>` |
| User type      | `isNormalUser`/`isSystemUser` | Not set         |
| Password gen   | Enabled via `clan.core.vars`  | Skipped         |
| `mutableUsers` | `false`                       | Not set         |
| Root SSH keys  | Collected from sudo users     | Skipped         |

### Machine-Specific Overrides

Override any user property per machine:

- `position` - Different role on this machine
- `uid` - Different UID (rare, but supported)
- `groups` - Replace default groups entirely
- `extraGroups` - Add groups to defaults
- `shell` - Different shell on this machine (string name)
- `sshAuthorizedKeys` - Replace SSH keys
- `extraSshAuthorizedKeys` - Add SSH keys to defaults

### Shell Resolution

Shells are specified as string names (e.g., `"fish"`, `"zsh"`, `"bash"`) and resolved to `pkgs.${name}` inside the generated NixOS/Darwin module. This keeps the interface JSON-serializable while supporting all standard shells.

### Automatic Features

- **Password Generation**: Based on position's `generatePassword` flag (NixOS only)
- **Root SSH Access**: Users with `sudoAccess = true` get SSH keys added to root (NixOS only)
- **Immutable Users**: Sets `users.mutableUsers = false` for security (NixOS only)

### Configuration Precedence

1. Machine specific overrides
2. User defaults
3. Position defaults

### Optional Position Flag Overrides

Individual position flags can be overridden per-user or per-machine without changing positions:

**Per-User Override** (applies to all machines):

```nix
users.alice = {
  uid = 1001;
  defaultPosition = "basic";
  sudoAccess = true;  # Override: grant sudo despite "basic" position
};
```

**Per-Machine Override** (applies to specific machine):

```nix
machines.prod-server = {
  users.alice = {
    generatePassword = false;  # Don't generate password on this machine
  };
};
```

**Priority**: machine flag > user flag > position default > fallback defaults

**Fallback defaults** (when no position is set): `sudoAccess=false`, `generatePassword=false`, `homeDirectory=true`, `isSystemUser=false`
