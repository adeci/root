---
description = "Cloudflare tunnel for secure service exposure" categories = ["Networking"] features = ["inventory"]
---

# Cloudflare Tunnel

This module manages [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) (formerly Argo Tunnel), allowing secure exposure of local services to the internet without opening firewall ports.

## Overview

Cloudflare Tunnel creates an encrypted connection between your server and Cloudflare's edge network. Traffic flows through Cloudflare, providing DDoS protection, SSL termination, and access controls without exposing your server's IP address.

## Security Features

- **No inbound ports**: Services are exposed through outbound-only connections
- **Automatic TLS**: Cloudflare handles SSL certificates
- **API token via LoadCredential**: Secrets passed securely through systemd
- **Automatic DNS management**: CNAME records created/updated automatically
- **Secure defaults**: Unmapped requests return 404

## Role

### Default

The default role configures cloudflared to create tunnels and manage DNS records.

## Configuration Options

| Option       | Type    | Required | Description                                                   |
| ------------ | ------- | -------- | ------------------------------------------------------------- |
| `tokenName`  | string  | Yes      | Name for the API token group (e.g., "adeci", "work")          |
| `tunnelName` | string  | No       | Name for the Cloudflare tunnel (defaults to machine hostname) |
| `ingress`    | attrset | No       | Map of hostnames to backend services                          |

### Token Sharing

The `tokenName` option allows you to share a single Cloudflare API token across multiple instances and machines. All instances with the same `tokenName` will use the same token - you only enter it once.

Use different `tokenName` values for different Cloudflare accounts:

- `tokenName = "personal"` - Your personal Cloudflare account
- `tokenName = "work"` - Work/company account
- `tokenName = "client-xyz"` - Client's account

## Examples

### Basic Setup

```nix
# inventory/instances/cloudflare-tunnel.nix
{
  "my-tunnels" = {
    module = {
      name = "@onix/cloudflare-tunnel";
      input = "self";
    };
    roles.default = {
      machines.my-server = {
        settings = {
          tokenName = "personal";
          tunnelName = "my-services";
          ingress = {
            "app.example.com" = "http://localhost:3000";
            "api.example.com" = "http://localhost:8080";
          };
        };
      };
    };
  };
}
```

### Multiple Machines, Same Token

```nix
{
  "home-tunnels" = {
    module = {
      name = "@onix/cloudflare-tunnel";
      input = "self";
    };
    roles.default = {
      # Both machines use the same "adeci" token - only prompted once
      machines.server1 = {
        settings = {
          tokenName = "adeci";
          tunnelName = "server1-services";
          ingress = { "vault.example.com" = "http://localhost:8222"; };
        };
      };
      machines.server2 = {
        settings = {
          tokenName = "adeci";
          tunnelName = "server2-services";
          ingress = { "git.example.com" = "http://localhost:3000"; };
        };
      };
    };
  };
}
```

## API Token Setup

When deploying, clan will prompt for a Cloudflare API token. Create one at:
https://dash.cloudflare.com/profile/api-tokens

### Required Permissions

| Scope          | Resource          | Permission                    |
| -------------- | ----------------- | ----------------------------- |
| Account        | Cloudflare Tunnel | Edit                          |
| Zone           | DNS               | Edit                          |
| Zone Resources | Include           | All zones (or specific zones) |

**Note**: The "All zones" permission is required because the setup script needs to:

1. Look up zone IDs for your domains
2. Create/update DNS CNAME records
3. Create and manage tunnel configurations

If you want to restrict to specific zones, select "Include > Specific zone" and add each domain you'll use in ingress rules.

## How It Works

1. **First deployment**: Prompts for API token, creates tunnel in Cloudflare
2. **DNS setup**: Creates CNAME records pointing to the tunnel
3. **Subsequent deployments**: Reuses existing tunnel, updates DNS if needed
4. **Runtime**: cloudflared maintains persistent connection to Cloudflare edge

## Deployment

```bash
clan machines update <machine-name>
```

On first run, you'll be prompted for the Cloudflare API token.

## Troubleshooting

### Check tunnel status

```bash
systemctl status cloudflare-tunnel-setup-<tunnel-name>
systemctl status cloudflared-tunnel-<tunnel-name>
```

### View setup logs

```bash
journalctl -u cloudflare-tunnel-setup-<tunnel-name>
```
