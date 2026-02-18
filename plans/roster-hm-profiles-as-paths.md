# Roster HM Profiles: Enable Toggles → Path-Based Imports

## Goal

Refactor the roster's home-manager profile system from hardcoded `adeci.*.enable` toggles to path-based imports. This decouples roster from any specific HM module namespace, making it general enough to upstream into clan-core.

## Current Approach (Problem)

Profiles map names to lists of module-enable names:

```nix
# clan-inventory/instances/roster/default.nix
homeManagerProfiles = {
  base = [ "base-tools" "shell-tools" "dev-tools" "fish" "git" ];
  desktop = [ "desktop" ];
  darwin-desktop = [ "kitty" "karabiner" "aerospace" ];
};
```

Roster generates `adeci.${name}.enable = true` for each string:

```nix
# Generated inside mkPlatformModule
home-manager.users.alex = {
  adeci.base-tools.enable = true;
  adeci.shell-tools.enable = true;
  # ...
};
```

**Problems for upstreaming:**
- Hardcoded `adeci` namespace — other repos won't have `adeci.*` options
- Profiles can only toggle enables — no arbitrary HM config (programs, services, settings)
- Invisible dependency on `sharedModules` loading the right modules elsewhere
- Roster's codegen knows about the consuming repo's module structure

## Proposed Approach

Profiles map names to **file paths** (relative to flake root):

```nix
# clan-inventory/instances/roster/default.nix
homeManagerProfiles = {
  base = "home-manager/profiles/base.nix";
  desktop = "home-manager/profiles/desktop.nix";
  darwin-desktop = "home-manager/profiles/darwin-desktop.nix";
};
```

Roster generates **imports** instead of enable toggles:

```nix
# Generated inside mkPlatformModule
home-manager.users.alex = {
  imports = [
    (self + "/home-manager/profiles/base.nix")
    (self + "/home-manager/profiles/desktop.nix")
  ];
  home.stateVersion = config.system.stateVersion;
};
```

Profile files are self-contained HM modules:

```nix
# home-manager/profiles/base.nix
{
  adeci.base-tools.enable = true;
  adeci.shell-tools.enable = true;
  adeci.dev-tools.enable = true;
  adeci.fish.enable = true;
  adeci.git.enable = true;
}
```

## What Changes

### Interface (`clan-services/roster/default.nix`)

Change the type of `homeManagerProfiles` from `attrsOf (listOf str)` to `attrsOf str`:

```nix
# Before
homeManagerProfiles = lib.mkOption {
  type = lib.types.attrsOf (lib.types.listOf lib.types.str);
  description = "Named HM profiles mapping to lists of adeci.* module names to enable";
};

# After
homeManagerProfiles = lib.mkOption {
  type = lib.types.attrsOf lib.types.str;
  description = "Named HM profiles mapping to file paths (relative to flake root)";
};
```

Still JSON-serializable (string values).

### Module generation (`mkPlatformModule`)

Replace the enable-toggle codegen with import-based codegen:

```nix
# Before
let
  moduleNames = lib.unique (lib.concatMap expandHmProfile cfg.effectiveHmProfiles);
in {
  adeci = lib.listToAttrs (
    map (name: { inherit name; value.enable = true; }) moduleNames
  );
}

# After
let
  profilePaths = map (name: settings.homeManagerProfiles.${name}) cfg.effectiveHmProfiles;
in {
  imports = map (path: self + "/${path}") profilePaths;
}
```

This requires `self` in the module args — already available via `specialArgs` in this repo. For upstreaming, confirm clan-core passes the flake self-reference to service modules.

### New profile files

Create `home-manager/profiles/` directory with three files:

**`home-manager/profiles/base.nix`**
```nix
{
  adeci.base-tools.enable = true;
  adeci.shell-tools.enable = true;
  adeci.dev-tools.enable = true;
  adeci.fish.enable = true;
  adeci.git.enable = true;
}
```

**`home-manager/profiles/desktop.nix`**
```nix
{
  adeci.desktop.enable = true;
}
```

**`home-manager/profiles/darwin-desktop.nix`**
```nix
{
  adeci.kitty.enable = true;
  adeci.karabiner.enable = true;
  adeci.aerospace.enable = true;
}
```

### Inventory data

```nix
# clan-inventory/instances/roster/default.nix
homeManagerProfiles = {
  base = "home-manager/profiles/base.nix";
  desktop = "home-manager/profiles/desktop.nix";
  darwin-desktop = "home-manager/profiles/darwin-desktop.nix";
};
```

User and machine assignments stay exactly the same — no changes to `users.nix` or `machines.nix`.

### Eval tests

Update the HM profile expansion test to reflect single-path values instead of lists of module names.

## What Stays the Same

- `homeManagerProfiles` option name and overall shape (attrsOf)
- `users.*.homeManagerProfiles` (list of profile names per user)
- `machines.*.users.*.homeManagerProfiles` (nullable override)
- `machines.*.users.*.extraHomeManagerProfiles` (additive extras)
- `homeStateVersion` option
- Resolution priority: machine override > user default + extras
- Auto-enable `adeci.home-manager` when any user has profiles
- System users with profiles are skipped
- Profile name validation assertion

## Why This Is Better for Upstreaming

| Concern | Current (enable toggles) | Proposed (path imports) |
|---------|-------------------------|------------------------|
| Namespace coupling | Hardcoded `adeci.*` | None — roster is namespace-agnostic |
| Profile expressiveness | Only `*.enable = true` | Any HM config (programs, services, settings) |
| Module discovery | Invisible sharedModules dependency | Explicit paths — what you see is what you get |
| JSON-serializable | Yes (list of strings) | Yes (single string) |
| Boilerplate elimination | Yes | Yes |
| Inventory UX | `homeManagerProfiles = [ "base" ]` | `homeManagerProfiles = [ "base" ]` (identical) |

## Verification

After implementation:
- `nix build .#nixosConfigurations.modus.config.system.build.toplevel` (desktop NixOS)
- `nix build .#nixosConfigurations.sequoia.config.system.build.toplevel` (server NixOS)
- `nix build .#darwinConfigurations.malum.system` (Darwin)
- `nix build .#homeConfigurations.alex.activationPackage` (standalone HM)
- `nix build .#checks.x86_64-linux.eval-tests-roster` (eval tests)
- `nix fmt -- --fail-on-change` (formatting)
- `git add` new profile files before building (flake git tracking)
