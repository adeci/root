## Why

No CI exists for this infrastructure monorepo — machine configs are only validated
manually before deploy. Leviathan (256-core EPYC) sits underutilized as a compute
server with no build infrastructure wired up. Adding buildbot-nix gives automated
CI on every push/PR, and wiring leviathan as a remote builder lets workstations
offload heavy builds on demand.

## What Changes

- Add `buildbot-nix` and `harmonia` as flake inputs for CI and binary caching
- New `adeci.buildbot-master` NixOS module on sequoia (controller, web UI, GitHub integration)
- New `adeci.buildbot-worker` NixOS module on leviathan (build executor, 256 cores)
- New `adeci.harmonia` NixOS module on leviathan (self-hosted binary cache serving the nix store over HTTP)
- New `adeci.remote-builder` NixOS module for workstations/laptops (offload builds to leviathan via SSH, with automatic/intentional toggle)
- New cloudflare tunnel route for `buildbot.decio.us` on sequoia
- Vars generators for all secrets (GitHub App credentials, worker passwords, signing keys, SSH keys)

## Capabilities

### New Capabilities

- `buildbot-master`: Buildbot controller with GitHub App integration, web UI, and worker coordination
- `buildbot-worker`: Buildbot build executor connecting to a remote master over TCP
- `harmonia-cache`: Self-hosted nix binary cache serving the local store to tailnet peers
- `remote-builder`: Distributed nix building via SSH with automatic/intentional modes

### Modified Capabilities

_(none)_

## Impact

- **Flake inputs**: New `buildbot-nix` input (does NOT follow nixpkgs — pins its own), new `harmonia` input (follows nixpkgs)
- **Sequoia**: Gains PostgreSQL, nginx, and buildbot master services; new cloudflare tunnel route
- **Leviathan**: Gains buildbot worker, harmonia, and accepts remote builder SSH connections
- **Workstation/laptop machines**: Gain `nix.buildMachines` config and harmonia substituter
- **Secrets**: 4 new shared vars generators (GitHub secrets, worker password, signing key, SSH key)
- **External setup required**: GitHub App creation, OAuth App creation, Cloudflare DNS record
