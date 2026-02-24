## ADDED Requirements

### Requirement: Harmonia module option

The module `modules/nixos/harmonia.nix` SHALL define `adeci.harmonia.enable`
as an `mkEnableOption`. When disabled, no harmonia configuration SHALL be
applied.

#### Scenario: Module disabled by default

- **WHEN** a machine does not set `adeci.harmonia.enable = true`
- **THEN** no harmonia service or signing key configuration is applied

#### Scenario: Module enabled on leviathan

- **WHEN** `adeci.harmonia.enable = true` is set in leviathan's config
- **THEN** harmonia runs and serves the nix store over HTTP

### Requirement: Harmonia service enabled

The module SHALL import the upstream harmonia NixOS module from the `harmonia`
flake input (`inputs.harmonia.nixosModules.harmonia`). When enabled, it SHALL
configure `services.harmonia-dev.cache` with `enable = true` and `signKeyPaths`
pointing to the signing key from the vars generator, and
`services.harmonia-dev.daemon.enable = true`.

#### Scenario: Binary cache serving

- **WHEN** harmonia is running on leviathan
- **THEN** other tailnet machines can fetch store paths from
  `http://leviathan:5000`

### Requirement: Signing key vars generator

A shared vars generator named `harmonia-signing-key` SHALL be defined only
in the harmonia module. This means only machines with `adeci.harmonia.enable = true`
become sops recipients for the private key. Other machines that need the public
key SHALL read it from git via `builtins.readFile` without declaring the generator.

Generator specification:

- No prompts (auto-generated)
- Files: `signing-key` (secret), `signing-key.pub` (`secret = false`)
- Script: use `nix-store --generate-binary-cache-key` to create the key pair
  with cache name `leviathan-harmonia-1`
- `runtimeInputs`: `nix`

#### Scenario: Key pair generated

- **WHEN** `clan vars generate` runs the `harmonia-signing-key` generator
- **THEN** a nix binary cache signing key pair is created, with the private
  key encrypted via sops only for leviathan, and the public key stored in git

#### Scenario: Public key readable by other machines

- **WHEN** the remote-builder module needs the harmonia public key
- **THEN** it reads from `self + "/vars/shared/harmonia-signing-key/signing-key.pub/value"`
  without declaring the generator or becoming a sops recipient

### Requirement: Nix allowed-users for harmonia

When harmonia is enabled, `nix.settings.allowed-users` SHALL include
`"harmonia"` so the harmonia service user can read the nix store.

#### Scenario: Harmonia can access store

- **WHEN** harmonia is running
- **THEN** the harmonia user can read store paths to serve them over HTTP
