# AGENTS.md

NixOS/Darwin infrastructure monorepo using flake-parts, Clan, Terranix,
and explicit package outputs. Keep the repo split clean: data in
`inventory/`, buildable outputs in `packages/`, reusable logic in
`modules/`, host composition in `machines/`.

## System

NixOS. Use the dev shell when possible:

```bash
nix develop
```

For tools outside the dev shell, use:

```bash
nix run nixpkgs#<package>
nix shell nixpkgs#<package> -c <command>
```

## Validate Changes

Run the smallest validation that proves your change. Before calling work done,
format and evaluate the affected outputs.

```bash
# Required by CI
nix fmt

# NixOS machine eval
nix eval .#nixosConfigurations.<machine>.config.system.build.toplevel.drvPath

# Darwin machine eval only
nix eval .#darwinConfigurations.<machine>.config.system.primaryUser

# Current-system checks
nix eval .#checks.x86_64-linux --json

# Terraform config package
nix build .#packages.x86_64-linux.tf-plan --no-link
```

Do not run full `nix flake check`; it tries to evaluate systems that are not
valid on this builder. Do not run `clan machines update`; deployment is a
manual decision.

## Hard Boundaries

Do not touch these unless explicitly asked:

- `sops/` and `vars/`: encrypted secrets.
- `flake.lock`: input updates.
- `facter.json`: generated hardware facts.

Keep large runtime state out of the system closure. Leviathan's local LLM
weights belong under `/var/lib/llm-weights`, not in NixOS toplevels.

## Repo Model

- `inventory/`: pure data: users, resources, Clan machine/role assignment.
- `packages/`: buildable configured outputs: wrappers, patched apps, helper
  CLIs, installer tools.
- `modules/flake-parts/`: flake wiring. These modules expose inventory,
  packages, checks, Terranix commands, Clan config, and other flake outputs.
- `modules/nixos/` and `modules/darwin/`: portable OS integration modules.
  Importing a module enables a capability.
- `modules/clan/`: custom Clan services for coordinated multi-machine config.
- `modules/terranix/`: Terraform/Terranix logic for external APIs/resources.
- `machines/<name>/`: host composition and machine-specific modules.

Use `modules/nixos/` or `modules/darwin/` for reusable capabilities. Use
`machines/<name>/modules/` only when config is tightly coupled to one host.

## Packages

`packages/default.nix` is an explicit registry, not directory discovery. It has
two groups: `wrappers` and `packages`.

```nix
{
  wrappers = {
    zsh = {
      path = ./zsh;
    };
  };

  packages = {
    vesktop = {
      path = ./vesktop;
      systems = [ "x86_64-linux" ];
      checks = false;
    };
  };
}
```

Rules:

- Entry shape is `{ path, systems?, checks? }`.
- `systems = null` is the default and means all flake systems.
- `checks = true` is the default.
- Set `systems` only when an output cannot evaluate/build everywhere.
- Set `checks = false` for heavy GUI packages or packages not worth routine
  checks.

`modules/flake-parts/packages.nix` validates the registry and interprets it:

- `packages.<name>.path` -> `self.packages.${system}.<name>` via
  `pkgs.callPackage`.
- `wrappers.<name>.path` -> `self.wrappers.<name>` and
  `self.packages.${system}.<name>` via nix-wrapper-modules.

System modules should install `self.packages.${system}.<name>` and keep package
implementation in `packages/`.

## Wrapper Conventions

Wrappers are pure configured packages: no runtime writes to `$HOME`.

Prefer wrapper composition through `self.wrappers.<name>.wrap` when extending a
wrapper:

```nix
zsh = self.wrappers.zsh.wrap {
  inherit pkgs;
};
```

Keep wrappers decoupled on installed systems where possible. For example, niri
can reference `kitty` by name from `PATH` instead of baking a specific kitty
store path into the compositor config.

## Data Exports

`self.users` comes from `inventory/users/`. Import user modules explicitly in
machines that need them.

```nix
imports = [ self.users.alex.nixosModule ];
```

`self.resources` comes from `inventory/resources/`. Terraform modules and OS
modules consume shared resource data from there.

## Infrastructure Choices

Use Terraform/Terranix when managing external resources with an API: cloud VMs,
DNS records, tunnels, buckets, RouterOS devices.

Use a Clan service when multiple machines need coordinated config, shared
secrets, generated keys, or cross-machine references.

Use a plain NixOS/Darwin module when config is local to a machine or a reusable
OS capability.

## Code Conventions

- Run `nix fmt`; it also enforces shellcheck, statix, deadnix, prettier, and
  nixfmt where configured.
- Use `pkgs.stdenv.hostPlatform.system`, not deprecated `pkgs.system`.
- Fix linter errors at the root cause; do not silence them.
- No home-manager. Use wrapped packages plus NixOS/Darwin modules.
- No custom option namespace just to wrap upstream config. Prefer plain modules
  that configure upstream options directly.
- Use `# bash` or `# zsh` before long multiline shell strings.
- Commented-out imports or nearby alternatives are usually intentional
  deployment/bookmark notes. Do not remove them unless asked.
- Flakes only see tracked files. Stage new files before relying on `nix eval` or
  `nix build`.

## Common Tasks

- Add a user: create `inventory/users/<name>.nix`, then import
  `self.users.<name>.nixosModule` or `.darwinModule` on machines.
- Add a reusable OS capability: create `modules/nixos/<name>.nix` or
  `modules/darwin/<name>.nix`, then import it from machines that need it.
- Add a package: create an implementation under `packages/`, then add it to
  `packages/default.nix` under `packages` or `wrappers`.
- Add machine-specific service wiring: put it under
  `machines/<name>/modules/` and import it from that machine.
- Add coordinated multi-machine behavior: create a custom Clan service under
  `modules/clan/`, register it, then add an instance under
  `inventory/clan/instances/`.
- Add external/API resources: put reusable logic in `modules/terranix/`; put
  machine-coupled resources in `machines/<name>/terraform-configuration.nix`.
- Add a RouterOS device: add inventory/resource data, netinstall it with the
  matching `routeros-netinstall-*` package, then manage it through the network
  Terranix workspace.
