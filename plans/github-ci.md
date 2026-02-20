# GitHub CI Adoption Plan

Inspired by [Mic92's dotfiles CI](https://github.com/Mic92/dotfiles), adapted for
our Clan-based infrastructure.

## What Mic92 Does

Mic92 has a comprehensive CI pipeline with 8 workflow files:

### Automated Updates (scheduled, daily)

| Workflow                   | Schedule                   | What it does                                                                                                                                                        |
| -------------------------- | -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `update-flake-inputs.yml`  | Daily 2am UTC              | Runs `mic92/update-flake-inputs` action → creates PR per changed input, auto-merges via GitHub App token                                                            |
| `update-packages.yaml`     | Daily 3am UTC              | Runs a custom Python `updater` CLI that discovers `pkgs/*/nix-update-args` or `pkgs/*/update.py` → creates one PR per package with `--pr` flag (uses git worktrees) |
| `update-submodules.yaml`   | Daily 2:51am UTC           | Updates zsh submodules → creates PR labeled `auto-merge`                                                                                                            |
| `update-nvim-plugins.yaml` | On PR (flake.lock changes) | When a flake-updater bot PR touches nixpkgs, runs `Lazy! update` headless → commits updated lazy-lock.json onto the same PR                                         |

### Auto-merge & Dependency Management

| Workflow          | Trigger               | What it does                                                                                 |
| ----------------- | --------------------- | -------------------------------------------------------------------------------------------- |
| `auto-merge.yaml` | `pull_request_target` | Runs `Mic92/auto-merge` action — auto-merges PRs from known bots (dependabot, flake-updater) |
| `dependabot.yml`  | Weekly                | Updates GitHub Actions, cargo, npm, terraform, pip dependencies → creates PRs                |

### AI-Assisted CI Fixes

| Workflow      | Trigger                                   | What it does                                                                                                                                            |
| ------------- | ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `claude.yaml` | `@claude` mentions in issues/PRs/comments | Checks out PR, runs a custom `buildbot-pr-check` tool to get CI status, invokes Claude Code Action to fix failures → creates a fix PR and comments back |

### Utility

| Workflow           | Trigger         | What it does                                                    |
| ------------------ | --------------- | --------------------------------------------------------------- |
| `os-ondemand.yaml` | Manual dispatch | Boots a chosen OS runner with `tmate` for interactive debugging |

### Build & Deploy (Buildbot, not GitHub Actions)

Mic92 uses **buildbot-nix** (self-hosted on his `eve` server) for the heavy
lifting — evaluating all NixOS configs, building derivations, and caching
outputs. His machines run an `update-prefetch` systemd timer that hourly
fetches the latest successful build from `buildbot.thalheim.io/nix-outputs/`
and pins it to `/run/next-system`. This is a **pull-based** deployment model —
machines pull their own pre-built closures from the Buildbot output cache.

He does NOT auto-deploy on merge. The machines pre-fetch the build artifacts,
but activating the new system is still a manual step (or done via
`nixos-rebuild switch` pointing at the pre-fetched path).

---

## What We Should Adopt

### Phase 1: Automated Flake Updates (Low effort, high value)

**`update-flake-inputs.yml`** — daily PR to update all flake inputs.

- Use `mic92/update-flake-inputs` or `DeterminateSystems/update-flake-lock` action
- Create a GitHub App for token generation (needed to trigger CI on bot PRs)
- Auto-merge if eval succeeds
- Our inputs: nixpkgs, clan-core, home-manager, nixvim, noctalia-shell,
  wrappers, niri, treefmt-nix, llm-agents, grub2-themes, devblog, trader-rs

**Considerations:**

- `trader-rs` uses SSH (`git+ssh://`), needs deploy key or skip
- `niri` is pinned to a fork branch — should probably be excluded until the
  upstream PR lands

### Phase 2: Eval Check on PRs (Medium effort, high value)

A workflow that runs `nix eval` (or `nix build --dry-run`) on every PR for all
machine configs. This catches breakage before merge.

```yaml
# Evaluate all NixOS + Darwin configs
nix eval .#nixosConfigurations.modus.config.system.build.toplevel
nix eval .#nixosConfigurations.claudia.config.system.build.toplevel
# ... etc for all machines
nix build .#darwinConfigurations.malum.system --dry-run
```

**Considerations:**

- Needs a self-hosted runner OR large GitHub runner for eval (Nix evals can be
  memory-hungry)
- Need to set up a binary cache (Cachix or Attic) to avoid rebuilding the world
- `trader-rs` and `devblog` inputs may need SSH keys in CI

### Phase 3: Dependabot for GitHub Actions (Trivial)

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
```

Keeps our own CI actions (once we have them) up to date.

### Phase 4: Auto-merge Bot PRs (Low effort)

Once we have update PRs flowing, add auto-merge for known bot PRs that pass
eval. Either:

- Use `Mic92/auto-merge` action
- Or configure GitHub's built-in auto-merge with branch protection rules

### Phase 5: Claude Code Action for CI Fixes (Medium effort, nice to have)

Wire up `anthropics/claude-code-action` to respond to `@claude` mentions on
PRs. Feed it eval/build errors and let it propose fixes.

Simpler than Mic92's version since we don't have Buildbot — just run the eval
check inline and pass failures to Claude.

### Phase 6: Custom Package Updates (Future)

We only have `vesktop` in `pkgs/` right now. If we accumulate more custom
packages, build an updater similar to Mic92's Python CLI (discovers
`nix-update-args` files, creates PRs per package).

---

## What We Should NOT Adopt

| Mic92 Feature                           | Why Skip                                                                                                    |
| --------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| **Buildbot-nix**                        | Heavy infrastructure. We use `clan machines update` for deployment — no need for a full CI build server yet |
| **update-prefetch (pull-based deploy)** | Only makes sense with Buildbot outputting to a cache. Our machines are updated directly via Clan            |
| **Nvim plugin updates**                 | We use nixvim, not a lazy.nvim setup with lock files                                                        |
| **Submodule updates**                   | We don't use git submodules                                                                                 |
| **Hercules CI effects**                 | Mic92's deploy effect is basically a no-op (`hello`). Not relevant                                          |
| **os-ondemand tmate**                   | Debugging utility, not a priority                                                                           |

---

## Implementation Order

```
Phase 1  →  Phase 3  →  Phase 2  →  Phase 4  →  Phase 5
(updates)   (depbot)    (eval CI)   (automerge)  (claude)
```

Phase 1 and 3 can be done immediately with zero infrastructure. Phase 2 needs
a cache strategy decision. Phases 4-5 build on top of having PR-based CI.

## Prerequisites

- [ ] Push repo to GitHub (if not already)
- [ ] Create a GitHub App for bot token generation (or use fine-grained PAT)
- [ ] Decide on binary cache (Cachix free tier vs self-hosted Attic)
- [ ] Add SSH deploy key for `trader-rs` input (if including in CI)
