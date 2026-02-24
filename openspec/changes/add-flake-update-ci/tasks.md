## 1. Workflow Files

- [ ] 1.1 Create `.github/workflows/update-flake-inputs.yml` with daily cron (02:00 UTC) and `workflow_dispatch` trigger
- [ ] 1.2 Add GitHub App token generation step using `actions/create-github-app-token`
- [ ] 1.3 Add checkout step with app token
- [ ] 1.4 Add Nix setup step using `DeterminateSystems/nix-installer-action`
- [ ] 1.5 Add `mic92/update-flake-inputs` step with `auto-merge: true` and exclude patterns for all inputs except `nixpkgs` and `llm-agents`
- [ ] 1.6 Create `.github/workflows/auto-merge.yml` triggering on `pull_request_target` using `Mic92/auto-merge`

## 2. Verify

- [ ] 2.1 Validate both workflow YAML files are well-formed
- [ ] 2.2 Confirm both files are `git add`ed
