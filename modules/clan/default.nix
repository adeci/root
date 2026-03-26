{ inputs }:
{
  "@adeci/roster" = import ./roster;
  "@adeci/tailscale" = import ./tailscale;

  "@adeci/siteup" = import ./siteup;
  "@adeci/harmonia" = import ./harmonia { inherit inputs; };
  "@adeci/trusted-caches" = import ./trusted-caches;
  "@adeci/remote-builder" = import ./remote-builder;
}
