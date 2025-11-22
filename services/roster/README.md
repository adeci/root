# Roster - Hierarchical User Management for Clan

A Clan service module that provides centralized, position-based user management across your fleet.

## Why Roster?

Unlike standard Clan user modules where user definitions are scattered across services and machines, Roster provides a **single source of truth** for user access. Define users once, then simply declare who has access to each machine.

## Key Differences from Clan Built-in Modules

| Aspect               | clan-core/users       | clan-core/admin       | Roster                             |
| -------------------- | --------------------- | --------------------- | ---------------------------------- |
| **User Definition**  | Per-service instance  | Per-service instance  | Once globally                      |
| **Machine View**     | Hunt through services | Hunt through services | `machines.<name>.users`            |
| **Permission Model** | Groups only           | Admin only            | Position hierarchy                 |
| **UID Management**   | Per-instance          | Per-instance          | Consistent across fleet            |
| **Override Pattern** | Redefine entirely     | Redefine entirely     | Inherit + override specific fields |

## Core Concepts

### Positions

Built-in permission levels that control user privileges:

| Position  | Sudo | Password Gen | Home Dir | Type   | Purpose                       |
| --------- | ---- | ------------ | -------- | ------ | ----------------------------- |
| `owner`   | ✅   | ✅           | ✅       | Normal | Primary machine administrator |
| `admin`   | ✅   | ✅           | ✅       | Normal | Secondary administrators      |
| `basic`   | ❌   | ✅           | ✅       | Normal | Regular users                 |
| `service` | ❌   | ❌           | ❌       | System | Service accounts              |

### Configuration Structure

```nix
{
  roster = {
    module = {
      name = "@onix/roster";
      input = "self";
    };
    roles.default = {
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

        # Step 1: Define users ONCE
        users = {
          alice = {
            uid = 1001;
            defaultPosition = "owner";
            description = "Alice Smith";
            groups = ["networkmanager" "docker"];
            sshAuthorizedKeys = ["ssh-ed25519 AAAA..."];
            defaultShell = "fish";
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

### Machine-Specific Overrides

Override any user property per machine:

- `position` - Different role on this machine
- `uid` - Different UID (rare, but supported)
- `groups` - Replace default groups entirely
- `extraGroups` - Add groups to defaults
- `shell` - Different shell on this machine
- `sshAuthorizedKeys` - Replace SSH keys
- `extraSshAuthorizedKeys` - Add SSH keys to defaults

### Automatic Features

- **Password Generation**: Based on position's `generatePassword` flag
- **Root SSH Access**: Users with `sudoAccess = true` get SSH keys added to root
- **Shell Management**: Automatically installs required shells
- **Immutable Users**: Sets `users.mutableUsers = false` for security

### Configuration Precedence

1. Machine specific overrides
2. User defaults
3. Position defaults

## Benefits

**Audit-Friendly**: Review `machines.<name>.users` to see all access at a glance
**Consistent UIDs**: Same UID across fleet prevents permission issues
**DRY Principle**: Define user details once
**Flexible**: Override anything per-machine when needed
