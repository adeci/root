# Remove Home-Manager Profile Management from Roster

## Summary

The roster clan service currently handles both user management AND
home-manager profile assignment. The HM part should be stripped out,
leaving roster as pure user/group/sudo/ssh management. HM config moves
to per-machine `home.nix` files with direct profile imports.

## Why

- The roster HM machinery is overengineered for our actual use case —
  it's almost always just alex on every machine with slightly different
  profile combos.
- The `adeci.x.enable` pattern in HM modules adds boilerplate (option
  declaration, mkIf guard) for a toggle that's rarely used. If you
  import a profile, you want its features — the enable flag is
  redundant indirection.
- Profile assignment via inventory (`extraHomeManagerProfiles`) is
  hard to read — you have to cross-reference roster/machines.nix with
  roster/default.nix to understand what a machine gets. Direct imports
  in a per-machine home.nix are immediately obvious.
- The roster service conflates two concerns: system-level user
  management (UIDs, groups, sudo, SSH keys) and user-space dotfile
  composition. These should be separate.

## Current Flow

1. `clan-inventory/instances/roster/default.nix` registers named HM
   profiles (e.g., `desktop = "profiles/home-manager/desktop.nix"`)
2. `clan-inventory/instances/roster/machines.nix` assigns profiles to
   users on machines via `homeManagerProfiles` / `extraHomeManagerProfiles`
3. Roster service resolves profiles → imports, wires up
   `home-manager.users.<name>` with the right profile modules
4. Each HM module uses `adeci.x.enable` option guarded by `mkIf`
5. Profiles are thin files that set `adeci.x.enable = true`

## Proposed Flow

1. Roster handles only: users, UIDs, groups, sudo, SSH keys, shells,
   passwords, system user flags
2. Each machine config does `home-manager.users.alex = import ./home.nix`
   (or similar)
3. Per-machine `home.nix` directly imports profiles:
   `imports = [ ../../profiles/home-manager/base.nix ... ]`
4. HM modules drop the `adeci.x.enable` wrapper — importing the file
   IS enabling the feature
5. Profiles become plain config files (packages, programs, settings)
   rather than flag-setters

## Models Compared

### Mic92 (fully decoupled)

- HM is a separate flake output, `home-manager switch` runs independently
- NixOS doesn't know about HM at all
- Pro: iterate on dotfiles without system rebuild, works on non-NixOS
- Con: two deployment steps, can drift between system and user config
- Not ideal for us: we use Clan for single-step deployment

### Surma (integrated, direct imports)

- `home-manager.users.surma = import ./home.nix` in machine config
- Per-machine home.nix imports profiles directly
- Pro: dead simple, immediately readable, one deployment step
- Con: some repetition across machines
- **Best fit for our setup** — keeps Clan single-step deployment,
  drops unnecessary abstraction

### Current (integrated, abstracted via roster)

- Roster service wires HM profiles from central inventory
- `adeci.x.enable` flags everywhere
- Pro: multi-user capable, centralized assignment
- Con: indirection for single-user, boilerplate, hard to trace

## What Stays

- `modules/home-manager/` directory structure (auto-discovery is fine)
- `profiles/home-manager/` as composable groupings
- Roster service for user/group management (just strip HM parts)

## What Changes

- HM modules lose `options.adeci.x.enable` + `mkIf` wrappers, become
  plain config
- Profiles change from `{ adeci.x.enable = true; }` to actual config
  (imports + settings)
- Roster loses: `homeManagerProfiles`, `extraHomeManagerProfiles`,
  `darwinHomeStateVersion`, and all HM wiring in `lib/generate.nix`
- Each machine gains a `home.nix` (or inline HM config)
- `modules/home-manager/default.nix` auto-discovery may need rethinking
  since modules would no longer be guarded by enable flags — importing
  all of them unconditionally would enable everything

## Migration Path

1. Create per-machine `home.nix` files that replicate current behavior
   using direct imports
2. Convert HM modules from option-guarded to plain config, one at a time
3. Strip HM-related options and logic from roster service
4. Remove profile registration from roster inventory
5. Verify each machine builds identically before and after

## Open Questions

- Should `modules/home-manager/default.nix` still auto-import everything?
  Without enable flags, auto-importing means everything is always on.
  Probably need to stop auto-importing and let profiles/home.nix do
  explicit imports instead.
- Keep a few `adeci.x.enable` flags for modules that genuinely need
  conditional behavior (e.g., platform-specific stuff)? Or handle that
  with `lib.optionals stdenv.isLinux` inside the modules?
- How to handle the kasha case (natalya as a separate user with
  different HM config)? Probably just a separate home-natalya.nix.
