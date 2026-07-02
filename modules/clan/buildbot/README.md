# @adeci/buildbot

Clan service for `buildbot-nix`.

## Roles

- `master` runs the Buildbot master, GitHub integration, nginx loopback vhost,
  worker registry, and Buildbot state registration.
- `worker` runs a Buildbot worker and receives its per-worker password.

`buildbot-nix` does not route jobs by worker architecture. Every worker can be
scheduled for every `buildSystems` entry, so workers enable Nix distributed
builds by default and rely on `@adeci/remote-builder` for per-system routing.
For a central binary cache, prefer running Buildbot workers on the cache host
only: remote builds execute elsewhere, but Nix copies results back to the
worker's store for gcroots and Harmonia.

## Inventory

```nix
{
  buildbot = {
    module = {
      name = "@adeci/buildbot";
      input = "self";
    };

    roles.master.machines.leviathan.settings = {
      domain = "buildbot.decio.us";
      useHTTPS = true;
      buildSystems = [
        "aarch64-linux"
        "x86_64-linux"
      ];
      evalWorkerCount = 32;
      evalMaxMemorySize = 4096;
      admins = [ "adeci" ];
      github = {
        appId = 3002742;
        oauthId = "Iv23...";
        topic = "build-with-buildbot";
      };
    };

    roles.worker.machines.leviathan.settings = {
      systems = [ "x86_64-linux" ];
      cores = 32;
    };
  };
}
```

The master opens the Buildbot worker port on `tailscale0` only when at least
one worker is remote. Workers that cannot locally build all master systems must
also be present under `@adeci/remote-builder.roles.client`; otherwise
cross-system jobs may be scheduled on a worker that cannot build them.

## Vars

Worker passwords have two layers:

- `buildbot-worker-password-<machine>` is the shared source secret. It is
  `share = true` and `deploy = false`, so the master can use it to render
  `workers.json` and the worker can derive its local runtime secret, but the
  raw shared source is not deployed by itself.
- `buildbot-worker-<machine>` is the per-machine runtime copy deployed only to
  that worker and used as `services.buildbot-nix.worker.workerPasswordFile`.

Master-only secrets:

- `buildbot-workers` renders `workers.json` from all worker source passwords.
- `buildbot-webhook-secret` is the GitHub webhook secret.
- `buildbot-github` stores the GitHub App private key and OAuth secret.

This keeps adding workers as an inventory-only change while avoiding deploy of
worker passwords to machines that do not need them.
