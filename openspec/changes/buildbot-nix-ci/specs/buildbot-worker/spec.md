## ADDED Requirements

### Requirement: Worker module option

The module `modules/nixos/buildbot-worker.nix` SHALL define
`adeci.buildbot-worker.enable` as an `mkEnableOption`. When disabled, no
buildbot worker configuration SHALL be applied. The module SHALL import
`inputs.buildbot-nix.nixosModules.buildbot-worker` via `specialArgs`.

#### Scenario: Module disabled by default

- **WHEN** a machine does not set `adeci.buildbot-worker.enable = true`
- **THEN** no buildbot worker services are configured

#### Scenario: Module enabled on leviathan

- **WHEN** `adeci.buildbot-worker.enable = true` is set in leviathan's config
- **THEN** `services.buildbot-nix.worker` is configured to connect to the master

### Requirement: Configurable master host

The module SHALL define `adeci.buildbot-worker.masterHost` as a string option
with default `"sequoia"` (tailscale hostname). The worker SHALL connect to
`tcp:host=<masterHost>:port=9989`.

#### Scenario: Default master connection

- **WHEN** the worker starts with default `masterHost`
- **THEN** it connects to `tcp:host=sequoia:port=9989` over tailscale

#### Scenario: Custom master host

- **WHEN** `adeci.buildbot-worker.masterHost = "other-host"` is set
- **THEN** the worker connects to `tcp:host=other-host:port=9989`

### Requirement: Configurable worker parallelism

The module SHALL define `adeci.buildbot-worker.workers` as an integer option
with default `0` (auto-detect from core count). This maps to the upstream
`services.buildbot-nix.worker.workers` option.

#### Scenario: Default parallelism

- **WHEN** `workers` is left at default `0`
- **THEN** buildbot-nix auto-detects available cores for parallel build slots

#### Scenario: Custom parallelism

- **WHEN** `adeci.buildbot-worker.workers = 4` is set
- **THEN** the worker runs 4 parallel build slots

### Requirement: Worker password from shared generator

The worker SHALL read its password from the `buildbot-workers` shared vars
generator's `password` file using `.path`.

#### Scenario: Password matches master

- **WHEN** both sequoia (master) and leviathan (worker) have run `clan vars generate`
- **THEN** the worker's password file contains the same password as the
  master's `workers.json` entry for leviathan

### Requirement: Leviathan nix build tuning

When the worker module is enabled on leviathan, the machine's `nix.settings`
SHALL configure `max-jobs` and `cores` for optimal build throughput on the
256-core EPYC system.

#### Scenario: Build resource limits set

- **WHEN** the worker is enabled on leviathan
- **THEN** `nix.settings.max-jobs` and `nix.settings.cores` are set to
  reasonable values that utilize most of the 256 logical cores without
  oversubscription
