# @adeci/nixbot

Clan service for [nixbot](https://github.com/Mic92/nixbot), the successor of
buildbot-nix.

## Roles

- `server` runs nixbot, its local PostgreSQL, the loopback nginx vhost (the
  public side is a Cloudflare tunnel) and the GitHub App secrets.

Builds go through the server's nix daemon. Systems it can't build itself go to
its `@adeci/remote-builder` machines.

The server rejects `nixbld` traffic to loopback, private ranges and the
tailnet, so fixed-output CI builds only reach DNS and the internet.

`effectSecrets."github:owner/repo" = [ "cachix" ];` adds a prompted var per
repo; effects read it with `readSecretString cachix .token`.

## GitHub App

- Callback URL: `https://<domain>/auth/github/callback`
- Webhook: active, `https://<domain>/webhooks/github`, secret from
  `clan vars get <machine> <instance>-webhook-secret/webhook-secret`
- Permissions: Checks read & write, Pull requests read-only (plus the usual
  contents/metadata/commit statuses)
- Events: push, pull request, check run, check suite

A public App lets anyone install it, and GitHub repo admins can enable their
own repos in nixbot. Set `github.userAllowlist` to bound which owners get
built, and `prApproval.enable` so fork PRs from authors without a merged
commit wait for a repo writer's "Approve CI" click.

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
      prApproval.enable = true;
      github = {
        appId = 5474567;
        oauthId = "Iv23...";
        userAllowlist = [ "adeci" ];
      };
    };
  };
}
```
