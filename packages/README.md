# Packages

My buildable configured outputs. These consist of [wrappers](https://github.com/BirdeeHub/nix-wrapper-modules), patched apps and overrides, helper tools, and some executable utilities/scripts.

`./default.nix` is a registry for all these outputs consumed by the [flake-parts packages module](../modules/flake-parts/packages.nix).

Registry entries are grouped by implementation type:

```nix
{
  wrappers = {
    foo = {
      path = ./foo;
    };
  };

  packages = {
    bar = {
      path = ./bar;
      systems = [ "x86_64-linux" ];
      checks = false;
    };
  };
}
```

Defaults:

- `systems = null` means all flake systems.
- `checks = true` means include in package checks.

`packages.<name>.path` entries are called with `pkgs.callPackage`. `wrappers.<name>.path` entries are exported through upstream `nix-wrapper-modules`, which provides both `self.wrappers.<name>.wrap` and `self.packages.${system}.<name>`.

System modules can install these with `self.packages.${system}.<name>`, and they are available as flake outputs for anyone to consume with `.#packages`!
