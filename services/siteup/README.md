---
description = "Deploy flake-based web applications" categories = ["Web"] features = ["inventory"]
---

# Siteup

Deploy web applications from flake inputs with automatic secrets management.

## Overview

Siteup is a generic service for running flake-based web applications. It handles:

- Running the application as a systemd service
- Setting up a dedicated user and working directory
- Managing secrets via clan vars (prompted once, stored encrypted)
- Environment variable configuration

Designed to work with cloudflare-tunnel for secure exposure.

## Configuration Options

| Option     | Type        | Required | Description                                          |
| ---------- | ----------- | -------- | ---------------------------------------------------- |
| `name`     | string      | Yes      | Unique name for this site instance                   |
| `flakeRef` | string      | Yes      | Name of the flake input (must match flake.nix input) |
| `package`  | string      | No       | Package attribute (default: "default")               |
| `port`     | int         | No       | Port (sets PORT env var). Optional if using args.    |
| `host`     | string      | No       | Bind address (default: "127.0.0.1")                  |
| `env`      | attrset     | No       | Non-secret environment variables                     |
| `secrets`  | list string | No       | Secret env var names to prompt for                   |
| `args`     | list string | No       | Command line arguments for the binary                |

## Examples

### Simple Site (No Secrets)

```nix
# flake.nix
inputs.devblog.url = "github:adeci/devblog";

# inventory/instances/siteup.nix
{
  "devblog" = {
    module.name = "@onix/siteup";
    roles.app.machines.myserver = {
      settings = {
        name = "devblog";
        flakeRef = "devblog";
        port = 3000;
      };
    };
  };
}
```

### Site with CLI Arguments

```nix
{
  "devblog" = {
    module.name = "@onix/siteup";
    roles.app.machines.myserver = {
      settings = {
        name = "devblog";
        flakeRef = "devblog";
        args = [ "--port" "4444" ];
      };
    };
  };
}
```

### Site with Secrets

```nix
# flake.nix
inputs.trader-rs.url = "git+ssh://git@github.com/user/trader-rs";

# inventory/instances/siteup.nix
{
  "trader" = {
    module.name = "@onix/siteup";
    roles.app.machines.myserver = {
      settings = {
        name = "trader";
        flakeRef = "trader-rs";
        port = 3001;
        env = {
          DATABASE_URL = "/var/lib/siteup/trader/trader.db";
        };
        secrets = [
          "TRADIER_API_KEY"
          "FINNHUB_API_KEY"
          "API_SECRET"
        ];
      };
    };
  };
}
```

### With Cloudflare Tunnel

```nix
# inventory/instances/cloudflare-tunnel.nix
{
  "my-tunnels" = {
    module.name = "@onix/cloudflare-tunnel";
    roles.default.machines.myserver = {
      settings = {
        tokenName = "myaccount";
        ingress = {
          "blog.example.com" = "http://localhost:3000";
          "app.example.com" = "http://localhost:3001";
        };
      };
    };
  };
}
```

## Private Repositories

For private repos, add them as flake inputs using SSH:

```nix
# flake.nix
inputs = {
  # Public
  my-public-site.url = "github:user/site";

  # Private via SSH (uses your SSH keys)
  my-private-site.url = "git+ssh://git@github.com/user/private-site";
};
```

Make sure your SSH keys are available on the machine building the configuration.

## How It Works

1. **Build time**: The flake input is built when you run `clan machines update`
2. **Deployment**: Systemd service is created with dedicated user
3. **Secrets**: Prompted once via clan vars, stored encrypted, loaded as env file
4. **Runtime**: Application runs in `/var/lib/siteup/<name>/` with configured env vars

## Service Management

```bash
# Check status
systemctl status siteup-<name>

# View logs
journalctl -u siteup-<name> -f

# Restart
systemctl restart siteup-<name>
```

## Working Directory

Each site gets its own working directory at `/var/lib/siteup/<name>/` with:

- Dedicated system user `siteup-<name>`
- Proper permissions for data storage (databases, uploads, etc.)
