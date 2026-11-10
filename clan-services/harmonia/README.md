# Harmonia Binary Cache

Serves the local nix store as a binary cache using
[harmonia](https://github.com/nix-community/harmonia), with automatic
client configuration via clan vars.

The signing key pair is generated automatically. Clients discover
servers and trust their public keys through the inventory — no manual
key distribution needed.

## Roles

### server

Runs the harmonia cache daemon and generates the signing key pair.

| Setting    | Type       | Default | Description                                |
| ---------- | ---------- | ------- | ------------------------------------------ |
| `port`     | `port`     | `5000`  | Port for the harmonia cache server         |
| `address`  | `str/null` | `null`  | Override address (defaults to host.domain) |
| `priority` | `int`      | `40`    | Default substituter priority for clients   |

### client

Configures nix to use harmonia servers as substituters.

| Setting    | Type       | Default | Description                              |
| ---------- | ---------- | ------- | ---------------------------------------- |
| `priority` | `int/null` | `null`  | Override priority (defaults to server's) |

## Requirements

The `harmonia` flake input must be available and passed to the service
module definitions.

## Example

```nix
harmonia = {
  module = { name = "@adeci/harmonia"; input = "self"; };
  roles.server.machines.my-builder = {
    settings.port = 5000;
  };
  roles.client.tags = [ "my-network" ];
};
```
