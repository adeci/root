{ inputs', ... }:
inputs'.clan-core.packages.clan-cli.overrideAttrs (old: {
  # Keep the Git subdirectory when evaluating, caching, and deploying a flake.
  patches = (old.patches or [ ]) ++ [ ./preserve-subflake-directory.patch ];
})
