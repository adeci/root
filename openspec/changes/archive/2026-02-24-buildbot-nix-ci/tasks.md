## 1. Flake Inputs

- [x] 1.1 Add `buildbot-nix` input to `flake.nix` (no nixpkgs follows)
- [x] 1.2 Add `harmonia` input to `flake.nix` (follows nixpkgs)

## 2. Vars Generators

- [x] 2.1 Create `buildbot-github` shared generator in buildbot-master module (3 secret prompts: app-secret-key, webhook-secret, oauth-secret)
- [x] 2.2 Create `buildbot-workers` shared generator in both master and worker modules (auto-gen password + workers.json with pwgen/jq)
- [x] 2.3 Create `harmonia-signing-key` shared generator in harmonia module (auto-gen nix binary cache key pair)
- [x] 2.4 Create `remote-builder-ssh-key` shared generator in remote-builder module (auto-gen ed25519 key pair)

## 3. NixOS Modules

- [x] 3.1 Create `modules/nixos/buildbot-master.nix` — import upstream module, define `adeci.buildbot-master.enable` + `admins` + `github.appId` + `github.oauthId` + `evalWorkerCount` options, wire `services.buildbot-nix.master` with domain/github/workers from vars
- [x] 3.2 Create `modules/nixos/buildbot-worker.nix` — import upstream module, define `adeci.buildbot-worker.enable` + `masterHost` + `workers` options, wire `services.buildbot-nix.worker` with master URL and password from vars
- [x] 3.3 Create `modules/nixos/harmonia.nix` — import upstream harmonia module from flake input, define `adeci.harmonia.enable`, enable `services.harmonia-dev.cache` + `services.harmonia-dev.daemon` with signing key from vars, set `nix.settings.allowed-users`
- [x] 3.4 Create `modules/nixos/remote-builder.nix` — define `adeci.remote-builder.enable` + `automatic` options, configure `nix.buildMachines` with leviathan, substituter with harmonia public key read from git via `builtins.readFile`, SSH key from vars, known hosts

## 4. Machine Configs

- [x] 4.1 Enable `adeci.buildbot-master` in `machines/sequoia/configuration.nix` with appId, oauthId, admins
- [x] 4.2 Enable `adeci.buildbot-worker` and `adeci.harmonia` in `machines/leviathan/configuration.nix`, tune nix.settings max-jobs/cores
- [x] 4.3 Add `"buildbot.decio.us" = "http://localhost:80"` to the cloudflare tunnel ingress in `clan-inventory/instances/`
- [x] 4.4 Add leviathan root authorized_keys for builder SSH public key via `builtins.readFile` from git

## 5. Validation

- [x] 5.1 Run `nix fmt` and fix any formatting issues
- [x] 5.2 Verify sequoia builds: `nix build .#nixosConfigurations.sequoia.config.system.build.toplevel` (eval succeeds; toplevel blocked by pre-existing home-manager/cheat.nix error)
- [x] 5.3 Verify leviathan builds: `nix build .#nixosConfigurations.leviathan.config.system.build.toplevel` (eval succeeds with stub public keys; toplevel blocked by same pre-existing home-manager/cheat.nix error; real keys from `clan vars generate`)
