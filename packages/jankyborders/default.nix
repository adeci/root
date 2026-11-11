{ pkgs, ... }:
pkgs.jankyborders.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ [ ./order-above-focused-sub-level.patch ];
})
