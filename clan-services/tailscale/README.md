# Tailscale

Enrolls machines in a [Tailscale](https://tailscale.com) tailnet with a clan
vars auth key and defaults subnet-route acceptance off. Everything else is
configured with the upstream `services.tailscale` options and the Tailscale
admin console.

## Roles

- `peer`: enrolls the machine with the instance's auth key and applies `flags`.
  On nix-darwin (no enrollment support) a launchd job runs `tailscale up` with
  the key only while the Mac is logged out, so its tags stay; once logged in it
  applies `flags` with `tailscale set`.

## Notes

- The auth key is prompted once per instance and shared by its peers: generate
  a reusable key in the Tailscale admin console, user-owned for machines that
  must reach devices shared to your user.
- On NixOS the Tailscale interface is trusted by the firewall: the tailnet
  policy limits who reaches which port.
- An expired key only stops new enrollments: existing machines stay connected,
  and new or rebuilt ones need a fresh key in the var.
- NixOS machines that should accept advertised routes set
  `services.tailscale.extraUpFlags = [ "--accept-routes" ]`,
  `extraSetFlags = [ "--accept-routes=true" ]` and
  `useRoutingFeatures = "client"`.
