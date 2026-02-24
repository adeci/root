## Context

The repo is a Nix flake with 14 inputs. Two inputs — `nixpkgs` and `llm-agents` — move frequently and should be kept up to date automatically. The remaining 12 inputs are either pinned intentionally or follow `nixpkgs` transitively. There are no existing GitHub Actions workflows. Mic92 maintains battle-tested actions for exactly this use case.

## Goals / Non-Goals

**Goals:**

- Automatically update `nixpkgs` and `llm-agents` on a daily schedule
- Create separate PRs per input so updates can be reviewed independently
- Auto-merge update PRs to minimize manual toil

**Non-Goals:**

- Updating all 14 flake inputs — only `nixpkgs` and `llm-agents` are in scope
- Running `nix flake check` or builds before merging — not worth the CI cost for input updates
- Managing the GitHub App creation — that's a one-time manual setup step

## Decisions

**Use `mic92/update-flake-inputs` action**
Handles everything: discovers inputs, creates per-input branches (`update-{input-name}`), opens PRs, manages idempotent updates. No need for matrix strategy or `peter-evans/create-pull-request`. Exclude the 12 inputs we don't want updated via `exclude-patterns` using the `flake.nix#input` syntax.

**Use `Mic92/auto-merge` action**
Companion action that triggers on `pull_request_target`, checks for the `dependencies` label (added by `update-flake-inputs` by default), and auto-merges. Simple, proven pairing.

**GitHub App token instead of `GITHUB_TOKEN`**
`GITHUB_TOKEN` doesn't trigger downstream workflows (GitHub's anti-loop protection). A GitHub App token allows CI to run on the created PRs. Requires one-time setup: create a GitHub App, store `APP_ID` and `APP_PRIVATE_KEY` as repo secrets.

**Daily cron schedule (02:00 UTC)**
Keeps inputs fresh. Since PRs are idempotent (one per input at a time), daily runs don't create noise if a previous PR hasn't been merged yet. Matches Mic92's own schedule.

**Exclude-pattern approach (not include)**
The action updates all inputs by default. We exclude the 12 we don't want: `**/flake.nix#clan-core,**/flake.nix#devblog,**/flake.nix#grub2-themes,...` etc. This way if we add new fast-moving inputs later, they're included by default.

## Risks / Trade-offs

- **[No pre-merge build check]** → Auto-merged updates could break things. Mitigated by: updates are just lockfile changes, and we can always revert. Mic92 runs this way successfully on his own infra.
- **[GitHub App setup required]** → One-time manual step. The `update-flake-inputs` repo has a web interface to simplify creation.
- **[Exclude list maintenance]** → When adding new flake inputs, they'll be auto-updated unless excluded. This is the right default — opt-out is better than opt-in for staying current.
