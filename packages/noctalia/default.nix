{ pkgs, ... }:
pkgs.noctalia.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ [ ./patches/lock-pam-service.patch ];
})
