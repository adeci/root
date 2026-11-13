{ inputs }:
let
  # Other clans use these services too, so each one carries this flake's inputs.
  service = module: {
    imports = [ module ];
    _module.args = { inherit inputs; };
  };
in
{
  "@adeci/atuin" = service ./atuin;
  "@adeci/harmonia" = service ./harmonia;
  "@adeci/monitoring" = service ./monitoring;
  "@adeci/nixbot" = service ./nixbot;
  "@adeci/remote-builder" = service ./remote-builder;
  "@adeci/restic" = service ./restic;
  "@adeci/security-keys" = service ./security-keys;
  "@adeci/tailscale" = service ./tailscale;
}
