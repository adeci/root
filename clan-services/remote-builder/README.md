# Remote Builder

Configures nix remote building with per-client SSH keys and a
dedicated `nix` build user. Each client generates its own key pair —
the server discovers and authorizes all client public keys
automatically.

## Roles

### server

Creates a `nix` system user for accepting remote builds. Authorizes
SSH keys from all client machines plus any external keys.

| Setting             | Type          | Default                               | Description                          |
| ------------------- | ------------- | ------------------------------------- | ------------------------------------ |
| `systems`           | `list of str` | `["x86_64-linux"]`                    | System types this builder offers     |
| `maxJobs`           | `int`         | `4`                                   | Max concurrent build jobs            |
| `speedFactor`       | `int`         | `1`                                   | Relative speed (higher = preferred)  |
| `supportedFeatures` | `list of str` | `["nixos-test" "big-parallel" "kvm"]` | Supported build features             |
| `externalKeys`      | `list of str` | `[]`                                  | SSH public keys for non-clan friends |

### client

Generates a per-machine SSH key pair. Self is excluded, so a machine can be
both a server and a client. Server authorization skips clients whose public key
has not been generated yet; run `clan vars generate <client>` before deploying
servers that should trust the new client.

`offload` decides which builds go remote automatically:

| Setting   | Type                           | Default     | Description                                                        |
| --------- | ------------------------------ | ----------- | ------------------------------------------------------------------ |
| `offload` | `"foreign"`, `"all"`, `"none"` | `"foreign"` | Only systems this machine can't build, anything servers offer, or nothing |

`foreign` keeps same-system builds local (cheaper for small builds, works
offline) while builds for other systems, like darwin from Linux, just work.
`/etc/nix/machines-all` always lists every server, for opting in per build
with `--builders @/etc/nix/machines-all --max-jobs 0`.

The server role is NixOS only.

## Example

```nix
builders = {
  module = { name = "@adeci/remote-builder"; input = "self"; };
  roles.server.machines.my-builder = {
    settings = {
      maxJobs = 16;
      speedFactor = 10;
      externalKeys = [
        "ssh-ed25519 AAAA... friend-name"
      ];
    };
  };
  roles.client.machines = {
    workstation-a = { };
    workstation-b = { };
  };
};
```
