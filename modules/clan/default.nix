{ inputs }:
{
  "@adeci/tailscale" = import ./tailscale;
  "@adeci/harmonia" = import ./harmonia { inherit inputs; };
  "@adeci/trusted-caches" = import ./trusted-caches;
  "@adeci/remote-builder" = import ./remote-builder;
  "@adeci/security-keys" = import ./security-keys;
  "@adeci/monitoring" = import ./monitoring;
  "@adeci/restic" = import ./restic;
  "@adeci/nixbot" = import ./nixbot { inherit inputs; };
}
