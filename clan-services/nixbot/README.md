# @adeci/nixbot

Clan service for [nixbot](https://github.com/Mic92/nixbot), the successor of
buildbot-nix.

## Roles

- `server` runs nixbot, its local PostgreSQL, a loopback-only nginx vhost and
  the GitHub App secrets. Something on the machine, such as a tunnel or reverse
  proxy, must forward the public `<domain>` to that vhost.

Builds go through the server's nix daemon. Systems it can't build itself need
nix remote builders (`nix.buildMachines` with `nix.distributedBuilds`), which
this service does not configure.

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

    roles.server.machines.ci-server.settings = {
      domain = "nixbot.example.com";
      buildSystems = [
        "aarch64-linux"
        "x86_64-linux"
      ];
      admins = [ "github:<login>" ];
      prApproval.enable = true;
      github = {
        appId = 123456;
        oauthId = "Iv23...";
        userAllowlist = [ "<login>" ];
      };
    };
  };
}
```
