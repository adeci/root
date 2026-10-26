# @adeci/nixbot

Clan service for [nixbot](https://github.com/Mic92/nixbot), the successor of
buildbot-nix.

## Roles

- `server` runs nixbot, its local PostgreSQL, the loopback nginx vhost (the
  public side is a Cloudflare tunnel) and the GitHub App secrets.

Builds go through the server's nix daemon. Systems it can't build itself go to
its `@adeci/remote-builder` machines.

## GitHub App

- Callback URL: `https://<domain>/auth/github/callback`
- Webhook: active, `https://<domain>/webhooks/github`, secret from
  `clan vars get <machine> <instance>-webhook-secret/webhook-secret`
- Permissions: Checks read & write, Pull requests read-only (plus the usual
  contents/metadata/commit statuses)
- Events: push, pull request, check run, check suite

## Inventory

```nix
{
  nixbot = {
    module = {
      name = "@adeci/nixbot";
      input = "self";
    };

    roles.server.machines.leviathan.settings = {
      domain = "nixbot.decio.us";
      buildSystems = [
        "aarch64-linux"
        "x86_64-linux"
      ];
      admins = [ "github:adeci" ];
      github = {
        appId = 5474567;
        oauthId = "Iv23...";
      };
    };
  };
}
```
