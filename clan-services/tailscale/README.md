# Tailscale

Enrolls machines in a [Tailscale](https://tailscale.com) tailnet with a clan
vars auth key and defaults subnet-route acceptance off. Everything else is
configured with the upstream `services.tailscale` options and the Tailscale
admin console.

## Roles

- `peer`: on NixOS, passes the auth key and `flags` to the upstream
  `services.tailscale` module, with `extraSetFlags` defaulting to
  `--accept-routes=false` plus `flags`. On nix-darwin, which has no enrollment
  support, a launchd job runs `tailscale up` with the auth key,
  `--accept-routes=false` and `flags`.

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
