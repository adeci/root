# Tailscale

Enrolls machines in a [Tailscale](https://tailscale.com) tailnet with a clan
vars auth key and defaults subnet-route acceptance off. Everything else is
configured with the upstream `services.tailscale` options and the Tailscale
admin console.

## Roles

- `peer`: enrolls the machine with the instance's auth key and applies `flags`.
  On nix-darwin, which has no enrollment support, a launchd job runs
  `tailscale up` instead.

## Notes

- The auth key is prompted once per instance and shared by its peers: generate
  a reusable key in the Tailscale admin console, user-owned for machines that
  must reach devices shared to your user.
- An expired key only stops new enrollments: existing machines stay connected,
  and new or rebuilt ones need a fresh key in the var.
- NixOS machines that should accept advertised routes set
  `services.tailscale.extraUpFlags = [ "--accept-routes" ]`,
  `extraSetFlags = [ "--accept-routes=true" ]` and
  `useRoutingFeatures = "client"`.
