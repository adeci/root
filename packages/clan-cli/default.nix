{ inputs', ... }:
inputs'.clan-core.packages.clan-cli.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ [ ./preserve-subflake-directory.patch ];
})
