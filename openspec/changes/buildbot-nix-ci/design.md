## Context

This monorepo manages 8 NixOS machines and 1 Darwin machine via declarative Nix
configuration. There is no CI — machine configs are validated manually. Leviathan
(2× AMD EPYC Milan, 256 logical cores, 256GB RAM) is a multi-user compute server
with `trusted-users` already configured and commented-out build tuning, but no
build infrastructure wired up. Sequoia (i7-7700K, 64GB RAM) runs web services
(vaultwarden, siteup apps) behind a cloudflare tunnel on tailscale.

All machines are connected via tailscale. Secrets are managed through clan vars
generators with sops/age encryption. NixOS modules are auto-discovered from
`modules/nixos/` and follow the `adeci.<name>.enable` pattern.

## Goals / Non-Goals

**Goals:**

- Automated CI via buildbot-nix: evaluate `.#checks` on every push/PR, report
  status back to GitHub
- Leviathan as the primary build worker (256 cores)
- Self-hosted binary cache (harmonia) so builds are instantly available to all
  tailnet machines without an upload step
- Remote builder support so workstations can offload heavy `nix build` to
  leviathan, with an intentional/automatic toggle for laptops vs desktops
- All secrets managed via clan vars generators — no manual file placement

**Non-Goals:**

- Multi-arch builds (aarch64 workers) — future follow-up
- Off-network binary cache (Cachix/Attic) — harmonia on tailnet is sufficient
- Building Darwin configurations via CI — no Darwin workers
- Flake checks output — adding `.#checks` re-exports is a follow-up after CI is running

## Decisions

### NixOS modules, not clan services

buildbot-nix provides upstream NixOS modules (`buildbot-master`, `buildbot-worker`).
The topology is fixed: sequoia = master, leviathan = worker. This maps cleanly to
per-machine module enablement rather than tag-driven clan service assignment. Wrapping
them in `adeci.*` modules keeps the interface consistent while importing the upstream
modules internally.

Alternative: Full clan services with roles and tag-based assignment. Rejected because
the topology is static (2 specific machines) and the overhead of the clan service
pattern doesn't add value here.

### Shared vars generators for cross-machine secrets

The worker password must match between master (`workers.json`) and worker
(`password` file). Using `share = true` generators means one generation step
produces a single secret encrypted only for machines that declare the generator.
Both the master and worker modules declare `buildbot-workers`, so both sequoia
and leviathan become sops recipients — and only them.

For the harmonia signing key and remote builder SSH key, only the "server" side
needs the secret (private key). The "client" side only needs the public key,
which is `secret = false` and committed to git. Client modules read public
files via `builtins.readFile (self + "/vars/shared/…/value")` without declaring
the generator, avoiding unnecessary secret access.

Alternative: Per-machine generators with dependencies. Rejected because the shared
pattern is simpler and these secrets genuinely need to be identical across machines.

### Don't follow nixpkgs for buildbot-nix input

buildbot-nix pins `nixpkgs-unstable-small` and requires buildbot ≥ 4.3.0 with
custom patches. Following our nixpkgs would likely break it. The upstream
explicitly warns against this.

### Upstream harmonia flake input

nixpkgs has the harmonia package but not the NixOS service module. The upstream
`github:nix-community/harmonia` flake provides `nixosModules.harmonia` with
`services.harmonia-dev.cache` and `services.harmonia-dev.daemon`. This follows
Mic92's pattern (a buildbot-nix maintainer). The harmonia input CAN follow our
nixpkgs since it's compatible.

Alternative: Write our own systemd service wrapping the nixpkgs harmonia package.
Rejected — the upstream module handles systemd sandboxing, socket activation,
and daemon configuration properly.

### Harmonia over Cachix

Harmonia serves leviathan's nix store directly over HTTP — zero upload step, zero
cost, zero external dependency. Since all machines are on tailscale, reachability
isn't an issue. Builds are available the instant they finish.

Alternative: Cachix (hosted SaaS). Rejected for now — adds cost, upload latency,
and external dependency for no benefit when everything is on tailnet.

### Remote builder uses root SSH

Nix remote building needs store access on the target. Using `root` with a dedicated
SSH key is the simplest and most common pattern. The key is restricted to tailscale
network access.

Alternative: Dedicated `nix-builder` user with nix daemon access. More complex
setup for marginal security benefit on an already-authenticated tailscale network.

### Automatic vs intentional remote building

Workstations (always-on, wired) get `nix.distributedBuilds = true` — transparent
offloading. Laptops get the buildMachines config but `distributedBuilds = false`,
requiring explicit `--builders` or `--max-jobs 0` flags. This prevents surprise
network-dependent builds on spotty connections.

## Risks / Trade-offs

- **Sequoia resource pressure** → Buildbot master is lightweight (postgres + web UI + webhook handler). Evaluated builds run on the worker, not the master. Risk is low.
- **Tailscale dependency** → All inter-machine communication (worker↔master, remote builds, harmonia) goes over tailscale. If tailscale is down, CI and remote builds break. Acceptable — local builds still work.
- **Cross-machine public file reads** → The harmonia signing public key and remote builder SSH public key need to be readable by machines that don't declare those generators. Using `builtins.readFile (self + "/vars/shared/…/value")` for public files avoids adding unnecessary sops recipients, but requires `clan vars generate` to run before first `nix build`.
- **Single worker** → If leviathan goes down, CI stops. No redundancy. Acceptable for a personal infrastructure repo.
- **Port 80 on sequoia** → buildbot-nix enables nginx. Other services (vaultwarden, siteup) use direct port routing via cloudflare tunnel, so no conflict, but nginx is now a new service on sequoia.
