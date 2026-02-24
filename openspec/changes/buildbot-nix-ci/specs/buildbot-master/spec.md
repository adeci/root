## ADDED Requirements

### Requirement: Flake inputs

The flake SHALL declare:
- `buildbot-nix` input pointing to `github:nix-community/buildbot-nix` — SHALL
  NOT follow the repo's nixpkgs (it pins its own for buildbot compatibility)
- `harmonia` input pointing to `github:nix-community/harmonia` — SHALL follow
  the repo's nixpkgs

#### Scenario: Flake inputs exist with correct follows

- **WHEN** the flake inputs are evaluated
- **THEN** `inputs.buildbot-nix` uses its own nixpkgs pin and
  `inputs.harmonia` uses the repo's nixpkgs

### Requirement: Master module option

The module `modules/nixos/buildbot-master.nix` SHALL define
`adeci.buildbot-master.enable` as an `mkEnableOption`. When disabled, no
buildbot master configuration SHALL be applied. The module SHALL import
`inputs.buildbot-nix.nixosModules.buildbot-master` via `specialArgs`.

#### Scenario: Module disabled by default

- **WHEN** a machine does not set `adeci.buildbot-master.enable = true`
- **THEN** no buildbot master services, PostgreSQL, or nginx configuration is applied

#### Scenario: Module enabled on sequoia

- **WHEN** `adeci.buildbot-master.enable = true` is set in sequoia's config
- **THEN** `services.buildbot-nix.master` is configured with domain, GitHub
  integration, and worker file references

### Requirement: Master domain and HTTPS

The master SHALL be configured with `domain = "buildbot.decio.us"` and
`useHTTPS = true` (URLs use `https://` since cloudflare terminates TLS).
The nginx virtualHost SHALL NOT enable ACME — TLS is handled by cloudflare.

#### Scenario: Web UI accessible via HTTPS

- **WHEN** a user navigates to `https://buildbot.decio.us`
- **THEN** the buildbot web UI is served via cloudflare → nginx → buildbot

### Requirement: GitHub App integration

The master module SHALL expose options for non-secret GitHub values:

- `adeci.buildbot-master.github.appId` — integer, the GitHub App ID
- `adeci.buildbot-master.github.oauthId` — string, the GitHub OAuth client ID

These are public identifiers set directly in the machine config (not secrets).

The master SHALL configure `services.buildbot-nix.master.github` with:

- `appId` from the module option
- `oauthId` from the module option
- `appSecretKeyFile` from the `buildbot-github` vars generator (secret file path)
- `webhookSecretFile` from the `buildbot-github` vars generator (secret file path)
- `oauthSecretFile` from the `buildbot-github` vars generator (secret file path)
- `topic` set to `"build-with-buildbot"`

#### Scenario: GitHub config uses options for public values and vars for secrets

- **WHEN** the master module is enabled and vars have been generated
- **THEN** `appId` and `oauthId` are set from module options, while
  secret files are read from vars generator paths

### Requirement: GitHub secrets vars generator

A shared vars generator named `buildbot-github` SHALL be defined with:

- Prompts: `app-secret-key` (multiline-hidden), `webhook-secret` (hidden),
  `oauth-secret` (hidden) — all with `persist = true`
- Files: `app-secret-key` (secret), `webhook-secret` (secret), `oauth-secret` (secret)
- Script: copy each prompt to its corresponding output file

#### Scenario: Generating GitHub secrets

- **WHEN** `clan vars generate` is run for the first time
- **THEN** the user is prompted for the 3 GitHub secret values and they are
  encrypted via sops

### Requirement: Worker credentials vars generator

A shared vars generator named `buildbot-workers` SHALL be defined with:

- No prompts (auto-generated)
- Files: `password` (secret), `workers.json` (secret)
- Script: generate a random 32-character password, write it to `password`,
  and write `[{"name":"leviathan","pass":"<password>","cores":128}]` to `workers.json`
- `runtimeInputs`: `pwgen`, `jq`

#### Scenario: Worker credentials auto-generated

- **WHEN** `clan vars generate` runs the `buildbot-workers` generator
- **THEN** a random password is generated and both `password` and `workers.json`
  files are created with matching credentials

### Requirement: Master worker file reference

The master SHALL set `workersFile` to the `workers.json` file path from the
`buildbot-workers` vars generator.

#### Scenario: Master reads worker credentials

- **WHEN** the buildbot master starts
- **THEN** it reads the workers file from the vars-managed secret path
  containing leviathan's name, password, and core count

### Requirement: Build systems configuration

The master SHALL set `buildSystems = ["x86_64-linux"]`.

#### Scenario: Only x86_64-linux builds

- **WHEN** buildbot evaluates a flake's checks
- **THEN** only `x86_64-linux` check attributes are built

### Requirement: Eval worker count

The master module SHALL expose `adeci.buildbot-master.evalWorkerCount` as an
optional integer option, passed through to `services.buildbot-nix.master.evalWorkerCount`.
This controls how many parallel nix-eval-jobs processes run during flake evaluation.

#### Scenario: Custom eval parallelism

- **WHEN** `adeci.buildbot-master.evalWorkerCount = 4` is set
- **THEN** the master runs 4 parallel nix-eval-jobs workers during evaluation

### Requirement: Admin users

The master SHALL configure an `admins` list. The option SHALL be configurable
via `adeci.buildbot-master.admins`.

#### Scenario: Admin can reload projects

- **WHEN** an admin user logs into the buildbot web UI
- **THEN** they can trigger project reloads and manage builds

### Requirement: Cloudflare tunnel route

The existing `sequoia-services` cloudflare tunnel instance SHALL include
`"buildbot.decio.us" = "http://localhost:80"` in its ingress rules.

#### Scenario: Traffic routes through tunnel

- **WHEN** a request arrives for `buildbot.decio.us` via cloudflare
- **THEN** it is routed through the tunnel to nginx on sequoia port 80
  which proxies to the buildbot web process
