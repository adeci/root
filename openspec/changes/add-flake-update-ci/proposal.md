## Why

Flake inputs (`nixpkgs` and `llm-agents`) drift behind upstream. Manually running `nix flake update` per-input is easy to forget, and stale inputs mean missing security patches and new packages. Automated, scheduled updates via GitHub Actions keep inputs fresh with minimal effort.

## What Changes

- Add a GitHub Actions workflow using `mic92/update-flake-inputs` to automatically update flake inputs daily, creating separate PRs per input
- Exclude all inputs except `nixpkgs` and `llm-agents` via `exclude-patterns`
- Add a companion `Mic92/auto-merge` workflow to automatically merge update PRs
- Use a GitHub App token so created PRs trigger CI workflows

## Capabilities

### New Capabilities

- `flake-update-workflow`: GitHub Actions workflows for daily flake input updates with auto-merge, using `mic92/update-flake-inputs` and `Mic92/auto-merge`

### Modified Capabilities

<!-- None — this is a new addition with no existing specs -->

## Impact

- New files: `.github/workflows/update-flake-inputs.yml`, `.github/workflows/auto-merge.yml`
- Requires GitHub Actions enabled on the repo
- Requires a GitHub App with Contents (write) and Pull Requests (write) permissions, configured as `APP_ID` and `APP_PRIVATE_KEY` repo secrets
- No changes to existing Nix configuration or flake structure
