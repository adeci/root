---
description = "Thin Clan auth-key glue for the upstream Tailscale NixOS module"
categories = ["Network", "System"]
features = ["inventory"]
---

# Tailscale

`@adeci/tailscale` assigns machines to a Tailscale instance, wires a Clan vars auth key into the upstream NixOS `services.tailscale` module, and defaults subnet-route acceptance off.

It otherwise does not wrap Tailscale behavior. Configure Tailscale normally in NixOS with upstream options such as `services.tailscale.extraUpFlags`, `services.tailscale.extraSetFlags`, and `services.tailscale.useRoutingFeatures`.

Tailscale SaaS remains the control plane. Auth keys are supplied through Clan var prompts so machines can enroll as user-owned devices when needed.

## Split of Responsibility

- Clan service: fleet assignment, auth-key prompt glue, and safe route default.
- Upstream NixOS module: all local `tailscaled` behavior.
- Tailscale admin console: SaaS account state, sharing, ACLs, and manually generated auth keys.

## Custom Option

Only one custom option exists:

- `auth-key-generator`: Clan vars generator name. Defaults to `tailscale-<instance>`.

## Example

```nix
{
  "adeci-net" = {
    module = {
      name = "@adeci/tailscale";
      input = "self";
    };
    roles.peer.tags = [ "adeci-net" ];
  };
}
```

Machine-specific Tailscale behavior belongs in normal NixOS config. Importing this Clan service defaults to:

```nix
{
  services.tailscale.extraSetFlags = lib.mkDefault [ "--accept-routes=false" ];
}
```

Override it on machines that should consume advertised routes:

```nix
{
  services.tailscale = {
    extraUpFlags = [ "--accept-routes" ];
    extraSetFlags = [ "--accept-routes=true" ];
    useRoutingFeatures = "client";
  };
}
```

## Auth Key Setup

Generate an auth key in the Tailscale admin console and provide it when Clan prompts for this service's `auth_key` var. Use user-owned keys for machines that must access devices shared to your Tailscale user.

## Auth Key Expiry

Auth-key expiry only controls future enrollment. Existing machines stay connected through their own Tailscale node state in `/var/lib/tailscale`.

If an auth key expires and a rebuilt/new machine needs to join, generate a new key in the Tailscale admin console and update the Clan var.

## Notes

Headscale cannot participate in Tailscale SaaS node sharing. Keep SaaS while shared nodes matter.
