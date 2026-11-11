# Atuin

Syncs shell history through a self-hosted [atuin](https://atuin.sh)
server. Clients find the server through the inventory and log in with one
shared account.

## Roles

### server

Runs the atuin sync server with registration closed. Its PostgreSQL
database is declared as clan state, so backups include it and a restore
stops the server while the database is replaced.

The server listens on all interfaces but opens no firewall port: clients
must reach it over an interface the firewall already admits.

| Setting   | Type       | Default | Description                                |
| --------- | ---------- | ------- | ------------------------------------------ |
| `port`    | `port`     | `8888`  | Port for the atuin server                  |
| `address` | `str/null` | `null`  | Override address (defaults to host.domain) |

The server role is NixOS only.

### client

Logs `user` in to the server at login, retrying every minute until the
server answers. The account's `username`, `password` and `key` (`atuin key`
on a logged-in machine) are prompted once into the `<instance>` vars
generator and shared by all clients.

Clients sync with exactly one server, exposed to other modules as
`atuinSync.address`.

| Setting | Type  | Default | Description                                   |
| ------- | ----- | ------- | --------------------------------------------- |
| `user`  | `str` |         | User who logs in and owns the account secrets |

## Example

```nix
atuin = {
  module = { name = "@adeci/atuin"; input = "self"; };
  roles.server.machines.my-server = { };
  roles.client.machines = {
    workstation-a = { };
    workstation-b = { };
  };
  roles.client.settings.user = "alice";
};
```
