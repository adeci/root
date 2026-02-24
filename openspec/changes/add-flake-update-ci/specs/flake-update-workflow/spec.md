## ADDED Requirements

### Requirement: Daily automated input updates

The workflow SHALL run daily on a cron schedule and update `nixpkgs` and `llm-agents` flake inputs, creating separate PRs per input.

#### Scenario: Daily scheduled run

- **WHEN** the cron schedule triggers (daily, 02:00 UTC)
- **THEN** the workflow SHALL run `mic92/update-flake-inputs` which creates or updates a PR per changed input

#### Scenario: Manual trigger

- **WHEN** a user manually triggers the workflow via `workflow_dispatch`
- **THEN** the workflow SHALL execute the same update process as the scheduled run

#### Scenario: Only targeted inputs are updated

- **WHEN** the workflow runs
- **THEN** all inputs except `nixpkgs` and `llm-agents` SHALL be excluded via `exclude-patterns`

### Requirement: Automatic PR merging

Update PRs SHALL be automatically merged via a companion auto-merge workflow.

#### Scenario: Update PR created with dependencies label

- **WHEN** `update-flake-inputs` creates a PR with the `dependencies` label
- **THEN** the `auto-merge` workflow SHALL automatically approve and merge the PR

### Requirement: GitHub App authentication

The workflow SHALL use a GitHub App token to authenticate, so that created PRs trigger CI workflows.

#### Scenario: PR triggers CI

- **WHEN** a PR is created by the update workflow
- **THEN** the PR SHALL trigger any configured CI workflows (unlike `GITHUB_TOKEN` which suppresses workflow triggers)

### Requirement: Idempotent PR management

Re-running the workflow for the same input SHALL update the existing PR branch rather than creating duplicates.

#### Scenario: PR already exists for input

- **WHEN** a PR for branch `update-{input}` already exists and the workflow runs again
- **THEN** the workflow SHALL update the existing branch and PR, not create a new one
