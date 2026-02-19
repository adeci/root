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

### Home-Manager Profile Distribution

Roster can distribute home-manager profiles to users across your fleet. Profiles are plain Nix files that enable modules or set HM config — roster maps them by name to file paths and imports them into each user's home-manager configuration.

#### Prerequisites

Roster sets `home-manager.users.<name>.imports` for each user that has profiles. For this to work, **you must have the home-manager NixOS/Darwin module loaded on your machines** with appropriate configuration:

```nix
# Example: a NixOS module that sets up home-manager infrastructure
{
  imports = [ inputs.home-manager.nixosModules.home-manager ];
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    sharedModules = [
      # Your home-manager modules go here — these make the options
      # referenced in your profiles available to all users
      ../modules/home-manager
    ];
    extraSpecialArgs = { inherit inputs self; };
  };
}
```

Roster does **not** configure this plumbing itself — it's intentionally separate so you control what modules and flake inputs are available to home-manager. Roster's job is purely the user-to-profile mapping.

#### Defining Profiles

Profiles are registered in the roster settings as a name-to-path mapping. Paths are relative to the flake root:

```nix
settings = {
  homeManagerProfiles = {
    base = "profiles/home-manager/base.nix";
    desktop = "profiles/home-manager/desktop.nix";
  };

  users = { ... };
  machines = { ... };
};
```

A profile file is a plain attrset (or module) that enables whatever you want:

```nix
# profiles/home-manager/base.nix
{
  my-namespace.shell.enable = true;
  my-namespace.git.enable = true;
}
```

#### Assigning Profiles to Users

Each user gets a default list of profiles. These apply on every machine the user is assigned to:

```nix
users.alice = {
  uid = 1001;
  defaultPosition = "owner";
  homeManagerProfiles = [ "base" ];  # applied everywhere
};
```

#### Per-Machine Profile Overrides

Add extra profiles for specific machines (e.g., desktop machines get a desktop profile):

```nix
machines.workstation = {
  users.alice = {
    extraHomeManagerProfiles = [ "desktop" ];  # added on top of user defaults
  };
};
```

You can also fully replace a user's profiles on a specific machine:

```nix
machines.server = {
  users.alice = {
    homeManagerProfiles = [ "base" ];  # replaces defaults entirely on this machine
  };
};
```

#### Profile Resolution

The final list of profiles for a user on a machine is:

1. Machine-specific `homeManagerProfiles` override (if set) — **replaces** defaults
2. Otherwise: user's `homeManagerProfiles` defaults + machine-specific `extraHomeManagerProfiles`

Roster validates that all referenced profile names exist in the `homeManagerProfiles` map and will fail with an assertion error if an unknown profile is used.
