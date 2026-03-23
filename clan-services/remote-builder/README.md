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
| `system`            | `str`         | `x86_64-linux`                        | System type this builder offers      |
| `maxJobs`           | `int`         | `4`                                   | Max concurrent build jobs            |
| `speedFactor`       | `int`         | `1`                                   | Relative speed (higher = preferred)  |
| `supportedFeatures` | `list of str` | `["nixos-test" "big-parallel" "kvm"]` | Supported build features             |
| `externalKeys`      | `list of str` | `[]`                                  | SSH public keys for non-clan friends |

### client

Generates a per-machine SSH key pair and configures `nix.buildMachines`
from all servers in the instance. `nix.distributedBuilds` is not set —
use `nrb` or `--builders` to opt in per build.

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
