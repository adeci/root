---
description = "Thin Clan auth-key glue for Tailscale on NixOS and nix-darwin"
categories = ["Network", "System"]
features = ["inventory"]
---

# Tailscale

`@adeci/tailscale` assigns machines to a Tailscale instance, supplies a Clan vars auth key, and defaults subnet-route acceptance off. Clan selects the implementation from each machine's `machineClass`:

- `nixos` (default): wires the auth key into the upstream NixOS `services.tailscale` module.
- `darwin`: enables nix-darwin's `services.tailscale` and adds a launchd job that runs `tailscale up` with the auth key, because nix-darwin has no enrollment support.

It otherwise does not wrap Tailscale behavior. Configure NixOS machines normally with upstream options such as `services.tailscale.extraUpFlags`, `services.tailscale.extraSetFlags`, and `services.tailscale.useRoutingFeatures`.

Tailscale SaaS remains the control plane. Auth keys are supplied through Clan var prompts so machines can enroll as user-owned devices when needed.

## Split of Responsibility

- Clan service: fleet assignment, auth-key prompt glue, Darwin enrollment, and safe route default.
- Upstream NixOS and nix-darwin modules: all other local `tailscaled` behavior.
- Tailscale admin console: SaaS account state, sharing, ACLs, and manually generated auth keys.

## Settings

- `auth-key-generator`: Clan vars generator name. Defaults to `tailscale-<instance>`.
- `flags`: Tailscale preferences for every peer in the instance on both platforms. NixOS passes them to `tailscale up` and, by default, `tailscale set`; Darwin passes them to `tailscale up` on each start.

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

Instance-wide preferences use `flags`:

```nix
{
  roles.peer.settings.flags = [ "--accept-dns=false" ];
}
```

Machine-specific Tailscale behavior belongs in normal machine config. On NixOS, importing this Clan service defaults to:

```nix
{
  services.tailscale.extraSetFlags = lib.mkDefault ([ "--accept-routes=false" ] ++ flags);
}
```

Override it on NixOS machines that should consume advertised routes:

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

Auth-key expiry only controls future enrollment. Existing machines stay connected through their own Tailscale node state. The Darwin job does not request forced reauthentication.

If an auth key expires and a rebuilt/new machine needs to join, generate a new key in the Tailscale admin console and update the Clan var.

## Notes

Headscale cannot participate in Tailscale SaaS node sharing. Keep SaaS while shared nodes matter.
