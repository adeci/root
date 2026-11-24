{ inputs, stdenv }:
inputs.clan-core.packages.${stdenv.hostPlatform.system}.clan-cli.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ [
    ./confirm-switch.patch
    ./cache-lock.patch
  ];
})
