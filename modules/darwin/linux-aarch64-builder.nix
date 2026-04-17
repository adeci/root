# stock nix.linux-builder — aarch64-linux only, QEMU/HVF can't plumb Rosetta.
# bootstrap for linux-rosetta-builder.nix: enable this first so its VM image can build locally.
{
  nix.linux-builder.enable = true;
}
