# Improvement Points

Assessment of the Root infrastructure monorepo after the sway/spud cleanup and desktop-base/deduplication work.

**Overall: 7/10**

---

## Ratings

| Category           | Score | Notes                                                                                  |
| ------------------ | ----- | -------------------------------------------------------------------------------------- |
| Architecture       | 8/10  | Clean layering, consistent patterns, good use of Clan                                  |
| Code quality       | 7/10  | Well-formatted, consistent style, no hacks — but hardcoded user and thin wrappers      |
| Deduplication      | 8/10  | Machine configs are lean, shared patterns extracted to modules                         |
| Roster service     | 9/10  | Best part of the repo. Novel, well-engineered, dual-platform                           |
| Documentation      | 5/10  | CLAUDE.md is great internally, README is thin, no inline docs, gitignore contradiction |
| Testability        | 3/10  | Builds pass, that's it. No VM tests, no CI, no assertions tested                       |
| Reference quality  | 5/10  | Too much implicit knowledge, hardcoded user, no explanation of "why"                   |
| Module design      | 6/10  | All-or-nothing enables, no configurable options pattern demonstrated                   |
| Secrets management | 6/10  | sops + clan vars exists but integration isn't documented or visible                    |

---

## Priority Fixes

### 1. Hardcoded "alex" everywhere

The roster manages user accounts but half the modules bypass it with literal `"alex"` strings:

- `modules/nixos/niri.nix` — `user = "alex"` in greetd
- `modules/nixos/ssh.nix` — `User alex` and `ForwardAgent`
- `modules/nixos/home-manager.nix` — hardcodes alex
- Every machine's `home-manager.users.alex` block

**Fix:** Add an `adeci.primaryUser` option (or derive it from roster's owner for the current machine) and reference it everywhere.

### 2. home.nix files are 90% identical boilerplate

Most machines import the same set of HM modules. This is what roster profiles were designed for but aren't being used.

**Fix:** Define HM profiles (e.g., "desktop-workstation", "server", "basic") in the roster or create a shared default home.nix.

### 3. No tests beyond "it builds"

Missing: NixOS VM tests, roster assertion tests, CI (GitHub Actions / Garnix).

**Fix:** Add at minimum `nix flake check` CI and one NixOS VM test showing "machine boots and user can login".

### 4. CLAUDE.md in .gitignore but tracked

The gitignore lists `CLAUDE.md` but the file is tracked. Confusing state.

**Fix:** Remove from .gitignore — it's useful documentation that should be shared.

### 5. README lacks depth

Doesn't explain: why Clan, how roster works, tag-based targeting, how to add services, how secrets flow.

**Fix:** Expand README with architectural decisions, a guided tour of data flow, and roster documentation.

---

## Module Design

### 6. All-or-nothing enables

Every module is just `adeci.foo.enable = true` with no configurability. Hardcoded values in ssh.nix (leviathan hostname), workstation.nix (swappiness), keyd.nix (keymapping).

**Fix:** Pick one or two modules and demonstrate the pattern of `enable` + configurable options + sensible defaults.

### 7. Thin wrappers may be over-abstraction

`amd-gpu.nix` is one line of config behind a 20-line module. `ssh.nix` is only used by 2 machines with network-topology-specific config.

**Guideline:** Modules earn their keep at 3+ consumers. Below that, consider whether the abstraction helps or just adds indirection.

### 8. Standalone homeConfiguration overlaps with roster

`flake-outputs/home-configurations.nix` defines a standalone HM config that enables the same modules the roster also generates. Two code paths doing related things.

**Fix:** Document when to use each, or consolidate.

---

## Cleanup

### 9. Dead machine: marine

`machines/marine/` exists but is commented out in inventory. Delete it or add a comment explaining why it's preserved.

### 10. desktop.nix coupling

`modules/home-manager/desktop.nix` directly references `noctalia-shell` flake input. Tight coupling makes it hard for others to understand or adapt.

---

## Reference Repo Aspirations

To make this a solid reference for others learning Nix/NixOS/Clan:

1. **Track CLAUDE.md** — it's one of the best parts of the repo
2. **Add CI** — GitHub Actions with `nix flake check` at minimum
3. **Add a "tour" document** — guided walkthrough of how inventory + services + modules produce a built system
4. **Extract roster** — it's good enough to be a standalone Clan service repo
5. **Show configurable module pattern** — demonstrate options beyond just `enable`
6. **Document secrets flow** — sops/vars integration is invisible to newcomers
