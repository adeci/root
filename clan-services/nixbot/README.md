# Nixbot

Runs [nixbot](https://github.com/Mic92/nixbot), the successor of buildbot-nix,
as a CI server for GitHub repositories.

## Roles

- `server` (NixOS only): runs nixbot with a local PostgreSQL and a
  loopback-only nginx vhost on `listenPort`. Something on the machine, such as
  a tunnel or reverse proxy, must forward the public `domain` to that vhost.

## Notes

- The server rejects `nixbld` traffic to loopback, private ranges and the
  tailnet, so fixed-output CI builds only reach DNS and the internet.
- The GitHub App needs:
  - callback URL `https://<domain>/auth/github/callback`
  - an active webhook to `https://<domain>/webhooks/github`, with the secret
    from `clan vars get <machine> <instance>-webhook-secret/webhook-secret`
  - permissions: Checks read & write, Pull requests read-only, plus the usual
    contents, metadata and commit statuses
  - events: push, pull request, check run, check suite
- A public App lets anyone install it and enable their repos: bound that with
  `github.userAllowlist` and `prApproval.enable`.
