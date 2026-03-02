# Leviathan Build Infrastructure

Status: **partially deployed**. Harmonia enabled on leviathan but not yet
deployed. Remote builder module exists and is enabled on praxis but vars
not yet generated. Buildbot CI fully stubbed but not activated.

## Current State

### Hardware

Leviathan is a 256 logical core AMD EPYC system. Nix is configured with
`max-jobs = 8`, `cores = 32` (8 × 32 = 256 cores utilized with headroom).

### What Exists

| Component               | Module                                 | Enabled Where                  | Deployed | Vars Generated               |
| ----------------------- | -------------------------------------- | ------------------------------ | -------- | ---------------------------- |
| Harmonia binary cache   | `modules/nixos/harmonia.nix`           | leviathan                      | **no**   | **yes** (signing keypair)    |
| Remote builder (client) | `modules/nixos/remote-builder.nix`     | praxis                         | **no**   | **no** (SSH keypair missing) |
| Remote builder (server) | `machines/leviathan/configuration.nix` | leviathan                      | **no**   | **no** (reads SSH pubkey)    |
| Buildbot master         | `modules/nixos/buildbot-master.nix`    | — (commented out on sequoia)   | no       | no                           |
| Buildbot worker         | `modules/nixos/buildbot-worker.nix`    | — (commented out on leviathan) | no       | no                           |

### What's Deployed Today

Nothing. Leviathan runs `base`, `dev`, `shell` with `auto-timezone`
disabled. It accepts SSH as root from roster users (alex, brittonr,
dima, fmzakari) but has no build infrastructure active.

---

## Component Details

### 1. Harmonia Binary Cache

**Module:** `modules/nixos/harmonia.nix`

Serves leviathan's nix store over HTTP on port 5000. Uses the
`harmonia-dev` service from the harmonia flake input. Auto-generates a
nix binary cache signing keypair via clan vars (`harmonia-signing-key`).

**Vars status:** Generated. Public key at
`vars/shared/harmonia-signing-key/signing-key.pub/value`, private key
encrypted at `vars/shared/harmonia-signing-key/signing-key/secret`.

**Config on leviathan:**

```nix
adeci.harmonia.enable = true;  # uncommented, not yet deployed
```

**What clients need:** Add leviathan as an `extra-substituter` with the
public signing key as a `trusted-public-key`. The `remote-builder.nix`
module does this automatically when the harmonia vars exist (conditional
on `builtins.pathExists`).

### 2. Remote Builder

**Client module:** `modules/nixos/remote-builder.nix`

Configures `nix.buildMachines` pointing at leviathan via `ssh-ng` as
root. Generates a shared ed25519 SSH keypair via clan vars
(`remote-builder-ssh-key`). Optionally enables harmonia substituter
when harmonia vars exist.

Key options:

- `adeci.remote-builder.enable` — main toggle
- `adeci.remote-builder.automatic` — default `false`. When `true`, sets
  `nix.distributedBuilds = true` (transparent offload, remote-first).
  When `false`, `buildMachines` is configured but the user opts in with
  `--max-jobs 0`.

Build machine spec:

```
hostName = "leviathan"
system = "x86_64-linux"
protocol = "ssh-ng"
maxJobs = 128
speedFactor = 10
supportedFeatures = [ "nixos-test" "big-parallel" "kvm" ]
sshUser = "root"
```

**Vars status:** Not generated. Need `clan vars generate praxis` (or any
machine that enables the module) to create the shared SSH keypair.

**Server side** (`machines/leviathan/configuration.nix`):

```nix
users.users.root.openssh.authorizedKeys.keys =
  lib.optional (builtins.pathExists builderKeyPath)
    (builtins.readFile builderKeyPath);
```

Reads the public key from `vars/shared/remote-builder-ssh-key/id_ed25519.pub/value`.
Uses `builtins.pathExists` so leviathan builds fine even when the key
doesn't exist yet — it just won't have the builder key in authorized_keys.

**Config on praxis:**

```nix
adeci.remote-builder.enable = true;  # added, not yet deployed
```

### 3. Buildbot CI

**Not active anywhere.** Fully implemented modules exist but are
commented out on their target machines.

**Master** (`modules/nixos/buildbot-master.nix`) — intended for sequoia:

- Needs a GitHub App (appId, oauthId) — placeholder TODOs in config
- Vars generator `buildbot-github` prompts for three secrets:
  app-secret-key (PEM), webhook-secret, oauth-secret
- Vars generator `buildbot-workers` auto-generates a worker password
  and workers.json
- Cloudflare tunnel route `buildbot.decio.us → localhost:80` already
  configured and waiting

**Worker** (`modules/nixos/buildbot-worker.nix`) — intended for leviathan:

- Connects to master at `sequoia` (default) with the shared worker
  password
- Options: `workers` (parallel slots, default auto from cores),
  `masterHost`

**To activate buildbot:** Create GitHub App → fill in TODOs on sequoia →
uncomment both master (sequoia) and worker (leviathan) → `clan vars
generate` for both → deploy both.

---

## Deployment Steps (Remote Builder + Harmonia)

Harmonia and remote builder are now decoupled — harmonia is a nice
bonus (serves cached builds over HTTP) but remote building works without
it.

### Minimum viable (remote building only)

1. `clan vars generate praxis` — creates `remote-builder-ssh-key`
2. `git add vars/`
3. Deploy leviathan (picks up the SSH pubkey in root's authorized_keys)
4. Deploy praxis (gets buildMachines config with the SSH private key)
5. Test: `nix build nixpkgs#hello --rebuild --max-jobs 0`

### Full stack (remote building + binary cache)

1. `clan vars generate praxis` — creates `remote-builder-ssh-key`
2. `git add vars/`
3. Deploy leviathan (harmonia starts serving on :5000, SSH key authorized)
4. Deploy praxis (buildMachines + harmonia substituter both active)
5. Test: `nix build nixpkgs#hello --rebuild --max-jobs 0`

Harmonia signing key vars already exist, so no additional generation
needed for leviathan.

---

## Usage

With `automatic = false` (current default), builds stay local unless
explicitly offloaded:

```bash
# Force all build jobs to leviathan
nix build .#something --max-jobs 0

# Normal local build (leviathan is configured but not used)
nix build .#something
```

If `automatic = true` were set, Nix would try remote first for every
build, falling back to local only when leviathan is full or unreachable.

---

## How Nix Distributed Build Scheduling Works

When remote builders are configured and the build hook is active
(`distributedBuilds = true` or `--builders` with hook enabled), Nix
evaluates every derivation against both local and remote capacity.

### Decision sequence

**1. Eligibility gates (hard filters)**

Each remote builder must match the derivation's `system` (e.g.,
`x86_64-linux`) and all its `requiredSystemFeatures`. A builder
missing any required feature is invisible to the scheduler for that
derivation. These are hard gates, not preferences.

**2. Local vs. remote priority**

Default: **remote first, local fallback.** From the Nix source:

```
// Default preference is a remote build: they tend to be faster
// and preserve local resources for other tasks.
```

Exception: derivations with `preferLocalBuild = true` (fetchers, trivial
shell wrappers) try local first, remote as fallback.

**3. Remote machine selection**

When multiple eligible remotes are available:

```
score = current_load / speedFactor    (lowest wins)
```

Tiebreakers: higher `speedFactor`, then lower absolute load.

Load is measured in real time using filesystem lock files. Each machine
gets `maxJobs` slot locks; occupied slots = active jobs.

**4. What happens when remotes are full**

- `max-jobs > 0`: hook responds `decline`, build falls back to local
  immediately
- `max-jobs = 0`: hook responds `postpone`, build waits in queue until
  a remote slot opens

**Key implication:** `--max-jobs 0` is the only way to truly force
remote. Without it, Nix will fall back to local whenever leviathan is
busy.

### `speedFactor` in practice

`speedFactor` divides the load count. An idle `speedFactor=1` machine
(score: 0) always beats a loaded `speedFactor=100` machine. It only
differentiates partially-loaded machines — e.g., load 2 with
`speedFactor=4` (score: 0.5) beats load 2 with `speedFactor=2`
(score: 1.0).

### `builders-use-substitutes`

Default `false`. When `true`, the remote builder fetches its own
dependencies from binary caches instead of having them uploaded from
the local machine. Dramatically faster for well-cached builds.

### Decision flow

```
Derivation ready to build
        │
        ▼
preferLocalBuild? ─── yes ──► Try local → remote fallback
        │
        no
        ▼
Filter remotes by system + system-features
        │
        ├── none eligible ──► local (or postpone if max-jobs=0)
        │
        ▼
Score: load / speedFactor → select lowest
        │
        ▼
Remote build dispatched
        │
        └── all full? ── max-jobs=0: postpone
                         max-jobs>0: build locally
```

---

## Opening Leviathan to Friends / External Machines

The current setup uses a clan-managed SSH keypair — great for our fleet,
useless for machines outside it. Two approaches for external users:

### Option A: Add their key to root's authorized_keys

Simple. They give you their public SSH key, you add it to leviathan:

```nix
# machines/leviathan/configuration.nix
users.users.root.openssh.authorizedKeys.keys = [
  # ... existing builder key ...
  "ssh-ed25519 AAAA... friend@their-machine"
];
```

They configure their side manually:

```nix
nix.buildMachines = [{
  hostName = "leviathan";  # or tailscale IP
  sshUser = "root";
  sshKey = "/path/to/their/private/key";
  system = "x86_64-linux";
  protocol = "ssh-ng";
  maxJobs = 128;
  speedFactor = 10;
}];
```

**Downside:** they're SSHing in as root. Fine for trusted friends, not
great as a pattern.

### Option B: Dedicated `nix-ssh` user (recommended for wider access)

Create a locked-down user on leviathan specifically for nix remote
builds:

- No interactive shell
- Added to `nix.settings.trusted-users` (required for remote builds)
- Own `authorizedKeys` you manage per-friend
- Cannot do anything except nix store operations

This is what Hydra and large build farms use. The nix daemon handles
authorization — the user just needs store access, not root.

**Not implemented yet.** Would be a small module or addition to
leviathan's config. The client-side `sshUser` in `buildMachines` would
change from `root` to `nix-ssh`.

### What friends need regardless of approach

- SSH access to leviathan (tailscale invite, or public IP + firewall rule)
- The machine spec for their `nix.conf` or NixOS config
- Optionally, harmonia substituter config if the binary cache is running

---

## Open Decisions

- [ ] Deploy harmonia + remote builder (minimum: just remote builder)
- [ ] `automatic = true` vs `false` — current default is `false` (opt-in
      per build). Could revisit after confirming stability.
- [ ] `nix-ssh` user for external access vs. root-only
- [ ] Buildbot CI activation (blocked on GitHub App creation)
- [ ] `builders-use-substitutes = true` on praxis — probably want this
      since leviathan has good bandwidth and cache.nixos.org access
- [ ] Enable remote-builder on other workstations (modus, aegis, kasha)
