# Atuin

Syncs shell history through a self-hosted [atuin](https://atuin.sh) server,
with every client logged in to one shared account.

## Roles

- `server` (NixOS only, one per instance): runs the atuin sync server with
  registration closed. Its PostgreSQL database is clan state, so backups
  include it.
- `client`: logs `user` in to the server at login, retrying every minute until
  it answers, and exposes the server URL as `atuinSync.address`.

## Notes

- Clients reach the server at `<server>.<clan domain>` unless it sets
  `address`. It opens no firewall port, so clients must reach it over an
  interface the firewall already admits.
- The account's username, password and key (`atuin key` on a logged-in
  machine) are prompted once and shared by all clients.
