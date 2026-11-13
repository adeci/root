{ moonshine }:
moonshine.overrideAttrs (old: {
  # Interfaces without a MAC (tailscale0) report 00:00:00:00:00:00, which Moonlight ignores; an empty one overwrites the MAC its wake button sends.
  patches = (old.patches or [ ]) ++ [ ./unknown-mac-as-zeros.patch ];
  meta = old.meta // {
    platforms = [ "x86_64-linux" ];
  };
})
