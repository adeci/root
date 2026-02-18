# Improvements Plan

Three priorities to move the repo from 7/10 to reference quality.

## Priority 1: Decompose the Roster Monolith

`clan-services/roster/default.nix` is 704 lines with a single `mkPlatformModule` function containing a ~240-line `let` block. It works correctly but the cognitive load is high — a newcomer has to hold the entire function in their head to understand any part of it.

### What to extract

Break `mkPlatformModule` into composed helper functions, each with a clear single responsibility:

1. **`resolveUserConfig`** — Takes a username + machine user config + global user def + positions, returns the fully resolved effective config (flags, uid, groups, shell, SSH keys, HM profiles). This is lines ~85-189 today.

2. **`mkPasswordGenerators`** — Takes the set of users needing passwords, returns the `clan.core.vars.generators` attrset. This is lines ~309-349 today.

3. **`mkUserAccounts`** — Takes all resolved user configs + platform flag, returns `users.users` attrset. This is lines ~260-294 today.

4. **`mkHomeManagerConfigs`** — Takes HM users + profile settings + platform flag, returns `home-manager.users` attrset. This is lines ~371-385 today.

5. **`validateRoster`** — Takes machine config + settings, returns the assertions list. This is the pre-validation block at lines ~66-82 and the assertions at ~243-257.

### Target structure

```
clan-services/roster/
  default.nix          # Service definition (manifest, roles, interface, perMachine)
  lib/
    resolve-user.nix   # resolveUserConfig
    passwords.nix      # mkPasswordGenerators
    accounts.nix       # mkUserAccounts
    home-manager.nix   # mkHomeManagerConfigs
    validate.nix       # validateRoster
  tests/
    eval-tests.nix     # (already exists)
  flake-module.nix     # (already exists)
  README.md            # (already exists)
```

### Rules

- Each helper is a pure function (takes args, returns attrset) — no module system, no `config` access except what's passed in.
- `mkPlatformModule` becomes a thin orchestrator that calls the helpers and assembles `lib.mkMerge`.
- The interface definition and `perMachine` stay in `default.nix` — only the implementation moves.
- Existing eval tests must still pass. Add focused tests for individual helpers.

---

## Priority 2: Thicken the Cross-Platform Story

The Darwin and standalone HM paths work but are thin — 1 Darwin machine, hardcoded architecture, no generic templates.

### 2a. Fix hardcoded x86_64-linux in standalone HM

`flake-outputs/home-configurations.nix` line 7:

```nix
system = "x86_64-linux";
```

Change to accept system as a parameter or provide multiple outputs:

```nix
# Option A: multiple outputs
flake.homeConfigurations = lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (system:
  let pkgs = import inputs.nixpkgs { inherit system; config.allowUnfree = true; };
  in { alex = inputs.home-manager.lib.homeManagerConfiguration { ... }; }
);

# Option B: per-system outputs (preferred — matches flake convention)
# alex-x86_64-linux and alex-aarch64-linux
```

Pick whichever approach matches how you actually use standalone HM. The point is: don't silently give someone x86 packages on aarch64.

### 2b. Add a generic NixOS machine template

Following surma-nixenv's `generic-*` pattern, add a minimal machine config that works out of the box for a fresh NixOS install:

```
machines/generic-nixos/
  configuration.nix   # Imports modules/nixos, enables base + shell + ssh
```

This lets someone clone the repo, point it at a new machine, and have a working base config without understanding the full inventory. The roster can assign just `alex` with base profile.

Add an entry to `clan-inventory/machines.nix` (commented out or with a placeholder tag) and document the workflow in README.md under "Add a machine."

### 2c. Document the Darwin setup path

The README "Add a machine" workflow only mentions NixOS files (`disko.nix`, `facter.json`). Add a Darwin variant:

```
**Add a Darwin machine:**
1. Create `machines/<name>/configuration.nix` importing `../../modules/darwin`
2. Set `nixpkgs.hostPlatform` and `system.stateVersion`
3. Add to `clan-inventory/machines.nix` with `machineClass = "darwin"` and empty tags
4. Add roster user assignments in `clan-inventory/instances/roster/machines.nix`
```

---

## Priority 3: Add Design Decisions Documentation

The README explains *what* and *how* but not *why*. Add a section or separate file explaining the key architectural choices. This is what makes a reference repo teachable.

### Location

Add a `## Design Decisions` section to README.md, after the current "How It Connects" section. Keep it concise — one paragraph per decision.

### Decisions to document

1. **Why Clan over plain NixOS flakes?**
   - Inventory-driven service assignment (declare once, deploy to tagged machines)
   - Built-in secrets management (vars + age)
   - Cross-platform support (NixOS + Darwin from one config)
   - What you'd have to build yourself without it

2. **Why a custom roster over `clan-core/users` and `clan-core/admin`?**
   - Single global user definition vs per-instance duplication
   - Position hierarchy vs flat groups
   - Machine-level overrides with inheritance
   - Consistent UIDs across fleet
   - Reference the comparison table in roster README

3. **Why `lassulus/wrappers` for dotpkgs?**
   - Packages are standalone (usable outside this repo via `nix run`)
   - Config is baked into the package, not dependent on HM/NixOS module system
   - Trade-off: less integration with system config, more portability

4. **Why profiles as plain attrsets instead of NixOS/HM modules?**
   - JSON-serializable (required by Clan interface)
   - Zero coupling to module system — a profile is just `{ adeci.foo.enable = true; }`
   - Composable: user defaults + machine extras via list concatenation

5. **Why auto-discovery modules instead of explicit imports?**
   - Zero boilerplate to add a module (drop file, it's available)
   - Trade-off: harder to see what's imported by reading one file
   - Convention-based: `adeci.*` namespace prevents collisions

---

## Bonus: Concrete Nitpicks to Fix Along the Way

These are small but affect the "reference quality" impression:

- [ ] Remove commented-out timezone in `machines/modus/configuration.nix` (`#time.timeZone = "Asia/Almaty"`)
- [ ] Move kitty out of `base-tools.nix` into a separate module or the desktop profile (it's a GUI app, not a base CLI tool)
- [ ] Resolve duplicate kitty configs: `dotpkgs/kitty/` (wrappers) vs `modules/home-manager/kitty/` (programs.kitty) — pick one approach
- [ ] Replace `_:` with `{ }:` in files that ignore their argument (`clan-services/default.nix`, `clan-inventory/instances/roster/default.nix`) for clarity
- [ ] Add a comment to `niri.url` in `flake.nix` with the upstream PR/issue link so someone knows when to switch back
- [ ] Absorb `hardware.amdgpu.opencl.enable`, `services.xserver.videoDrivers`, and `hardware.graphics` from `modus/configuration.nix` into the `amd-gpu` module — or document why they're separate
- [ ] Document the `dotpkgs/` wrapper pattern somewhere (even a one-liner in README)
