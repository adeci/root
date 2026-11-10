# Packages

Patched apps, overrides, helper tools and scripts. Configured programs live in
[`../wrappers`](../wrappers) instead.

[`flake/packages.nix`](../flake/packages.nix) finds every `<name>/default.nix`
here and calls it with `callPackage`, so adding a package is just adding its
folder. It is exported as `self.packages.<system>.<name>` on the systems its
`meta.platforms` allows; a package limited to one system says so there:

```nix
meta.platforms = [ "x86_64-linux" ];
```

A folder can also return a set of packages, exported as `<name>-<key>`:
`routeros-netinstall/` gives `routeros-netinstall-cap-ax`,
`routeros-netinstall-crs310` and `routeros-netinstall-crs328`.

Every package is also a flake check, except the heavy GUI builds listed in
`skipChecks` in `flake/packages.nix`.

Machines install packages with `self.packages.${pkgs.stdenv.hostPlatform.system}.<name>`.
Wrappers are turned on and tweaked per machine through `wrappers.<name>`
options instead (`modules/wrappers.nix`).
