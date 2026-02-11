---
description = "Vaultwarden password manager server" categories = ["Security"] features = ["inventory"]
---

# Vaultwarden

This module manages [Vaultwarden](https://github.com/dani-garcia/vaultwarden), a lightweight Bitwarden-compatible password manager server.

## Overview

Vaultwarden is an unofficial Bitwarden server implementation written in Rust. It's fully compatible with official Bitwarden clients and provides a self-hosted alternative for password management.

## Security Features

This module implements several security measures:

- **Argon2-hashed admin token**: The admin token is hashed with Argon2 before deployment. Even if the configuration is compromised, attackers cannot access the admin panel without cracking the hash.
- **Systemd hardening**: The service runs with extensive sandboxing (PrivateTmp, ProtectSystem, NoNewPrivileges, MemoryDenyWriteExecute, etc.)
- **Secure defaults**: Signups disabled, password hints hidden, invitations controlled by admin

## Role

### Server

The server role installs and configures Vaultwarden with hardened defaults.

## Configuration Options

Any Vaultwarden environment variable can be set within the settings attrset. This is made possible through the freeform type.

### Default Settings

| Setting               | Default                  | Description                             |
| --------------------- | ------------------------ | --------------------------------------- |
| `DOMAIN`              | `https://vault.decio.us` | Public URL of your Vaultwarden instance |
| `ROCKET_PORT`         | `8222`                   | HTTP port for the web interface         |
| `WEBSOCKET_PORT`      | `3012`                   | WebSocket port for real-time sync       |
| `SIGNUPS_ALLOWED`     | `false`                  | Disable public registration             |
| `INVITATIONS_ALLOWED` | `true`                   | Allow admin to invite users             |
| `SHOW_PASSWORD_HINT`  | `false`                  | Hide password hints for security        |

## Examples

### Basic Setup

```nix
# inventory/instances/vaultwarden.nix
{
  instances = {
    "my-vault" = {
      module = {
        name = "@onix/vaultwarden";
        input = "self";
      };
      roles.server = {
        machines.my-server = {
          settings = {
            DOMAIN = "https://vault.example.com";
          };
        };
      };
    };
  };
}
```

### With Cloudflare Tunnel

For secure external access without exposing ports:

```nix
# inventory/instances/vaultwarden.nix
{
  instances = {
    "my-vault" = {
      module = {
        name = "@onix/vaultwarden";
        input = "self";
      };
      roles.server.machines.my-server = {
        settings = {
          DOMAIN = "https://vault.example.com";
          # Vaultwarden listens on localhost, tunnel handles TLS
        };
      };
    };
  };
}

# inventory/instances/cloudflare-tunnel.nix
{
  instances = {
    "my-tunnel" = {
      module = {
        name = "@onix/cloudflare-tunnel";
        input = "self";
      };
      roles.default.machines.my-server = {
        settings = {
          ingress = {
            "vault.example.com" = "http://localhost:8222";
          };
        };
      };
    };
  };
}
```

## Admin Access

After deployment, your admin token is stored in the clan vars. To retrieve it:

```bash
# The plaintext token is stored locally (not deployed to machines)
cat vars/shared/vaultwarden-<instance-name>/admin_token_plaintext
```

Use this token to access the admin panel at `https://your-domain.com/admin`.

## Deployment

```bash
clan machines update <machine-name>
```

The admin token will be automatically generated on first deployment.
