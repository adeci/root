# Roster - Hierarchical User Management for Clan

A Clan service module that provides centralized, position-based user management across your fleet.

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
            defaultShell = pkgs.fish;  # Or your custom wrapped shell package
            packages = with pkgs; [  # Default packages on all machines
              git vim htop tmux
            ];
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
                shell = pkgs.bash;  # Override shell with different package
                extraPackages = with pkgs; [  # Add packages to defaults
                  docker-compose kubectl
                ];
                # Or replace all packages entirely:
                # packages = with pkgs; [ git neovim ];
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
- `packages` - Replace default packages entirely
- `extraPackages` - Add packages to defaults
- `homeModules` - Replace home-manager modules entirely
- `extraHomeModules` - Add home-manager modules to defaults

### Custom Shell Packages

Since shells are defined as package references, you can easily use custom wrapped shells:

```nix
users.alice = {
  # Use a custom fish with plugins
  defaultShell = pkgs.fish.overrideAttrs (old: {
    # Your customizations
  });

  # Or reference a custom shell package defined elsewhere
  defaultShell = myCustomZsh;

  # The custom shell package will be used directly
  # No need to include it in packages list
};
```

### Automatic Features

- **Password Generation**: Based on position's `generatePassword` flag
- **Root SSH Access**: Users with `sudoAccess = true` get SSH keys added to root
- **Immutable Users**: Sets `users.mutableUsers = false` for security

### Configuration Precedence

1. Machine specific overrides
2. User defaults
3. Position defaults

### Home-Manager Integration

Roster provides optional, first-class home-manager support. Define home-manager modules per user with machine-specific overrides.

**Requirements**: Add `home-manager` to your flake inputs:

```nix
inputs.home-manager.url = "github:nix-community/home-manager";
inputs.home-manager.inputs.nixpkgs.follows = "nixpkgs";
```

**Per-User Configuration**:

```nix
users.alice = {
  uid = 1001;
  defaultPosition = "owner";

  # Home-manager modules applied on all machines
  homeModules = [
    ./users/alice/home.nix
    ./users/alice/git.nix
    ({ pkgs, ... }: {
      home.packages = [ pkgs.ripgrep ];
    })
  ];
};
```

**Machine-Specific Overrides**:

```nix
machines.desktop = {
  users.alice = {
    # Add extra modules (merged with defaults)
    extraHomeModules = [
      ./users/alice/desktop.nix
      ./users/alice/gui-apps.nix
    ];
  };
};

machines.server = {
  users.alice = {
    # Override entirely (replaces defaults)
    homeModules = [
      ./users/alice/server-minimal.nix
    ];
  };
};
```

**Global Home-Manager Settings**:

```nix
homeManager = {
  useGlobalPkgs = true;      # Use system nixpkgs (recommended)
  useUserPackages = true;    # Install packages to user profile
  extraSpecialArgs = { };    # Extra args for all home modules
  sharedModules = [ ];       # Modules applied to ALL users
};
```

**Context Available in Home Modules**:

Home modules receive `rosterMachine` in their arguments:

```nix
{ rosterMachine, ... }:
{
  home.sessionVariables.MACHINE = rosterMachine;
}
```

**Conditional Behavior**:

- If no users have `homeModules`, home-manager is not imported
- If `homeModules` exist but `home-manager` input is missing, a warning is shown
- Only users with non-empty `effectiveHomeModules` get home-manager configuration
