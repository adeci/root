# dotpkgs

Wrapped tool packages with configs baked in. Uses [lassulus/wrappers](https://github.com/lassulus/wrappers) under the hood.

## Packages

btop, fish, fuzzel, git, kitty, mako, niri, starship, sway, swaylock, swayosd

## Adding a new package

1. Create a directory: `my-tool/`
2. Add `module.nix`:

```nix
{ pkgs, wrappers, ... }:
{
  my-tool =
    (wrappers.wrapperModules.my-tool.apply {
      inherit pkgs;
      "config-file".path = ./config-file;
    }).wrapper;
}
```

3. Drop in your config files. That's it. `default.nix` discovers new directories automatically.
