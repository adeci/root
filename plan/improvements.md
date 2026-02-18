# Improvements Plan

Two priorities plus nitpicks to move the repo toward reference quality.

## Priority 1: Decompose the Roster Monolith

`clan-services/roster/default.nix` is 704 lines with a single `mkPlatformModule` function containing a ~240-line `let` block. It works correctly but the cognitive load is high — a newcomer has to hold the entire function in their head to understand any part of it.

The decomposition should be easy to review for clan-core maintainers. Don't over-split into many tiny files, but don't leave it as one monolith either.

### What to extract

Split `mkPlatformModule` into two focused library files:

1. **`lib/resolve.nix`** — User resolution and validation. Takes settings + machine config, returns resolved user configs and validation assertions. This covers:
   - `getUserConfig` (resolving effective flags, uid, groups, shell, SSH keys, HM profiles via the machine > user > position precedence chain)
   - Pre-validation logic (undefined users, invalid positions, unknown profiles)
   - Assertion generation

2. **`lib/generate.nix`** — NixOS/Darwin config generation. Takes resolved user configs + platform flag + settings, returns the module config attrsets. This covers:
   - `users.users` account generation (platform-aware: isNormalUser, home paths, groups)
   - Password generators via `clan.core.vars.generators` (NixOS only)
   - Root SSH key collection from sudo users (NixOS only)
   - System user group creation (NixOS only)
   - `home-manager.users` config generation from resolved HM profiles
   - Owner detection for `adeci.primaryUser`

### Target structure

```
clan-services/roster/
  default.nix          # Service definition (manifest, roles, interface, perMachine)
                       # mkPlatformModule becomes thin orchestrator calling lib/
  lib/
    resolve.nix        # User resolution + validation
    generate.nix       # Platform-aware config generation
  tests/
    eval-tests.nix     # (already exists)
  flake-module.nix     # (already exists)
  README.md            # (already exists)
```

### Rules

- Each lib file exports a function that takes explicit args (lib, pkgs, settings, machine config, etc.) — no implicit module system access.
- `mkPlatformModule` becomes a thin orchestrator: calls `resolve`, passes results to `generate`, assembles `lib.mkMerge`.
- The interface definition (`roles.default.interface`) and `perMachine` stay in `default.nix` — only the implementation body moves.
- `defaultPositions` and `fallbackPositionConfig` stay in `default.nix` (they're configuration data, not logic).
- Existing eval tests must still pass. Run: `nix eval .#legacyPackages.x86_64-linux.eval-tests-roster`

---

## Priority 2: Fix Cross-Platform Standalone HM

### 2a. Fix hardcoded x86_64-linux in standalone HM

`flake-outputs/home-configurations.nix` hardcodes `system = "x86_64-linux"`. This needs to support both x86_64-linux and aarch64-darwin (for using standalone HM on a Mac outside the Clan fleet).

Generate per-system outputs with system-suffixed names:

```nix
# Produces: homeConfigurations.alex-x86_64-linux, homeConfigurations.alex-aarch64-darwin
flake.homeConfigurations = builtins.listToAttrs (
  map (system:
    let
      pkgs = import inputs.nixpkgs { inherit system; config.allowUnfree = true; };
    in {
      name = "alex-${system}";
      value = inputs.home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = { inherit inputs self; };
        modules = [
          inputs.noctalia-shell.homeModules.default
          ../modules/home-manager
          (import ../home-manager/profiles/base.nix)
          {
            home.username = "alex";
            home.homeDirectory = if pkgs.stdenv.isDarwin then "/Users/alex" else "/home/alex";
            home.stateVersion = "24.11";
          }
        ];
      };
    }
  ) [ "x86_64-linux" "aarch64-darwin" ]
);
```

Usage becomes:
```bash
home-manager switch --flake .#alex-x86_64-linux    # Linux
home-manager switch --flake .#alex-aarch64-darwin   # macOS
```

Update the "Standalone Home-Manager" section in README.md to show both commands.

### 2b. Document the Darwin setup path

The README "Add a machine" workflow only mentions NixOS files (`disko.nix`, `facter.json`). Add a Darwin variant to the Workflows section:

```
**Add a Darwin machine:**
1. Create `machines/<name>/configuration.nix` importing `../../modules/darwin`
2. Set `nixpkgs.hostPlatform` and `system.stateVersion`
3. Add to `clan-inventory/machines.nix` with `machineClass = "darwin"` and empty tags
4. Add roster user assignments in `clan-inventory/instances/roster/machines.nix`
5. `git add` the new files, then `nix build .#darwinConfigurations.<name>.system` to verify
```

---

## Nitpicks

These are small but affect polish. Work through them after the priorities above.

- [ ] Remove commented-out timezone in `machines/modus/configuration.nix` (`#time.timeZone = "Asia/Almaty"`)
- [ ] Move kitty out of `base-tools.nix` — it's a GUI terminal, not a base CLI tool. Move it to the desktop profile or a dedicated module.
- [ ] Replace `_:` with `{ }:` in files that ignore their argument (`clan-services/default.nix`, `clan-inventory/instances/roster/default.nix`) for clarity.
- [ ] Add a comment to `niri.url` in `flake.nix` with the upstream PR/issue link so someone knows when to switch back.
- [ ] Absorb AMD GPU config into the `amd-gpu` module: move `hardware.amdgpu.opencl.enable`, `services.xserver.videoDrivers = [ "amdgpu" ]`, and `hardware.graphics` (enable + enable32Bit) from `modus/configuration.nix` into `modules/nixos/amd-gpu.nix`. OpenCL is useful for all AMD GPU machines, not just modus.
- [ ] Document the `dotpkgs/` wrapper pattern somewhere (even a one-liner in README explaining what `lassulus/wrappers` does and why packages are wrapped this way).
