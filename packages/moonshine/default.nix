{ moonshine, ... }:
moonshine.overrideAttrs (old: {
  # On an interface without a MAC (tailscale0), report 00:00:00:00:00:00, which
  # Moonlight ignores; an empty one overwrites the MAC its wake button sends.
  patches = (old.patches or [ ]) ++ [ ./unknown-mac-as-zeros.patch ];
})
