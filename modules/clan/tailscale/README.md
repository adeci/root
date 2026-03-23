---
description = "Manages Tailscale VPN service" categories = ["Network", "System"] features = ["inventory"]
---

# Tailscale

This module manages the [Tailscale](https://tailscale.com/) VPN service, allowing easy connection to your Tailscale network.

## Overview

Tailscale is a zero-config VPN that creates a secure network between your devices. It works by establishing direct connections between devices when possible, and relays through their servers when not.

## Role

### Default

The default role installs and configures Tailscale with all features available.

## Configuration Options

Any Tailscale option from the NixOS module may be set within the settings attrset for any inventory instance. This is made possible through the freeform type.

### Custom Options

- `exitnode-optimization` (boolean): Enables kernel optimizations for better UDP throughput on exit nodes and subnet routers. Applies ethtool settings on boot for Linux 6.2+ kernels.

## Examples

### Basic Setup

```nix
# inventory/services/tailscale.nix
{
  instances = {
    "my-network" = {
      module.name = "tailscale";
      module.input = "self";
      roles.peer = {
        tags.tailnet = { };  # Deploy to all machines with 'tailnet' tag
      };
    };
  };
}
```

### Exit Node Configuration

```nix
{
  instances = {
    "my-network" = {
      module.name = "tailscale";
      module.input = "self";
      roles.peer = {
        tags.tailnet = { };

        # Configure gateway as exit node with optimizations
        machines.gateway = {
          settings = {
            exitnode-optimization = true;  # Enable kernel optimizations
            useRoutingFeatures = "server";
            extraUpFlags = [ "--advertise-exit-node" ];
          };
        };

        # Configure laptop to use exit node
        machines.laptop = {
          settings = {
            useRoutingFeatures = "client";
            extraUpFlags = [ "--exit-node=gateway" ];
          };
        };
      };
    };
  };
}
```

### Authentication

When deploying, clan will prompt for the Tailscale auth key which is then stored securely:

```bash
clan machines update <machine-name>
```
