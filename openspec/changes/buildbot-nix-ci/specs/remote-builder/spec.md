## ADDED Requirements

### Requirement: Remote builder module option

The module `modules/nixos/remote-builder.nix` SHALL define
`adeci.remote-builder.enable` as an `mkEnableOption`. When disabled, no
remote builder configuration SHALL be applied.

#### Scenario: Module disabled by default

- **WHEN** a machine does not set `adeci.remote-builder.enable = true`
- **THEN** no `nix.buildMachines` or substituter configuration is applied

### Requirement: Automatic mode toggle

The module SHALL define `adeci.remote-builder.automatic` as a boolean option
with default `true`. When `true`, `nix.distributedBuilds = true` — builds
transparently offload. When `false`, `nix.buildMachines` is still configured
but `distributedBuilds` is `false` — the user must explicitly opt in per build.

#### Scenario: Automatic mode for workstations

- **WHEN** `adeci.remote-builder = { enable = true; }` (default automatic)
- **THEN** `nix.distributedBuilds = true` and `nix build` transparently
  offloads to leviathan when beneficial

#### Scenario: Intentional mode for laptops

- **WHEN** `adeci.remote-builder = { enable = true; automatic = false; }`
- **THEN** `nix.distributedBuilds = false` but `nix.buildMachines` contains
  leviathan, allowing explicit use via `--builders` or `--max-jobs 0`

### Requirement: Build machine configuration

The module SHALL configure `nix.buildMachines` with a single entry for
leviathan:

- `hostName = "leviathan"` (tailscale hostname)
- `system = "x86_64-linux"`
- `protocol = "ssh-ng"`
- `maxJobs = 128`
- `speedFactor = 10`
- `supportedFeatures = ["nixos-test" "big-parallel" "kvm"]`
- `sshUser = "root"`
- `sshKey` from the `remote-builder-ssh-key` vars generator

#### Scenario: Build machine registered

- **WHEN** the remote builder module is enabled
- **THEN** `nix.buildMachines` contains leviathan with correct connection
  parameters and features

### Requirement: SSH key vars generator

A shared vars generator named `remote-builder-ssh-key` SHALL be defined in the
remote-builder module. Only machines with `adeci.remote-builder.enable = true`
become sops recipients for the private key. Leviathan SHALL read the public key
from git via `builtins.readFile` for its authorized_keys without declaring the
generator.

Generator specification:

- No prompts (auto-generated)
- Files: `id_ed25519` (secret), `id_ed25519.pub` (`secret = false`)
- Script: use `ssh-keygen -t ed25519 -N ""` to generate the key pair
- `runtimeInputs`: `openssh`

#### Scenario: SSH key pair generated

- **WHEN** `clan vars generate` runs the `remote-builder-ssh-key` generator
- **THEN** an ed25519 SSH key pair is created, with the private key encrypted
  via sops only for machines enabling the remote-builder module, and the public
  key stored in git

### Requirement: Leviathan accepts builder SSH key

Leviathan's configuration SHALL add the remote builder SSH public key to
`users.users.root.openssh.authorizedKeys.keys` by reading it from git via
`builtins.readFile (self + "/vars/shared/remote-builder-ssh-key/id_ed25519.pub/value")`.
This avoids leviathan declaring the generator and receiving the private key.

#### Scenario: Builder can SSH into leviathan

- **WHEN** a workstation with the remote builder module initiates a remote build
- **THEN** the SSH connection to leviathan as root succeeds using the
  generated key pair

### Requirement: Harmonia substituter configuration

When the remote builder module is enabled, the machine SHALL add leviathan's
harmonia as a substituter:

- `nix.settings.substituters` SHALL include `http://leviathan:5000`
- `nix.settings.trusted-public-keys` SHALL include the public key read from
  git via `builtins.readFile (self + "/vars/shared/harmonia-signing-key/signing-key.pub/value")`

The module SHALL NOT declare the `harmonia-signing-key` generator — it only
reads the public file from git to avoid becoming a sops recipient for the
private signing key.

#### Scenario: Cached builds fetched from harmonia

- **WHEN** a workstation needs a store path that exists on leviathan
- **THEN** it fetches the path from harmonia instead of rebuilding locally

### Requirement: SSH known hosts for leviathan

The module SHALL configure SSH to accept leviathan's host key for remote
builder connections. This MAY use `programs.ssh.knownHosts` with leviathan's
SSH public key or `StrictHostKeyChecking accept-new` scoped to the leviathan host.

#### Scenario: First connection succeeds without manual intervention

- **WHEN** a workstation initiates its first remote build to leviathan
- **THEN** the SSH connection succeeds without prompting for host key verification
