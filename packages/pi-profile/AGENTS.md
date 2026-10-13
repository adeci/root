# Environment

My machines use NixOS or nix-darwin. Check the current host rather than assuming Linux. Follow the repository's own `AGENTS.md` and use its development shell when available.

For missing tools, prefer Nix:

```sh
nix shell nixpkgs#<package> -c <command>
nix run nixpkgs#<package> -- <arguments>
```

Inside a flake repository, use `--inputs-from .` when the tool should come from that repository's pinned inputs. Do not update inputs just to obtain a tool.

## Find the Right Package

When a command or library is missing and its package is unclear, use `nix-locate` if available:

```sh
nix-locate --whole-name bin/rg
nix-locate --minimal --whole-name bin/tshark
nix-locate libssl.so
```

If the index is unavailable, inspect the repository's pinned package set or upstream package definitions. Do not repeatedly guess package names.

## Nix Development

- Inside a development shell, inspect available tools, `NIX_CFLAGS_COMPILE`, `NIX_LDFLAGS` and `PKG_CONFIG_PATH` before guessing dependency or include paths. Do not dump the full environment; it may contain credentials.
- Prefer Nix-provided dependencies when packaging. Do not introduce ad-hoc pip installs or virtual environments into a Nix build; preserve the project's existing workflow when developing.
- Prefer `nix eval` for a known output and the smallest relevant check or build. Avoid evaluating the whole flake when a targeted check proves the change.
- Before a cross-platform build, check the target system and available builders. Do not assume another architecture or operating system can build locally.
- Stage new files before evaluating a Git-backed flake; Nix cannot see untracked files. Leave unrelated staging unchanged.

## Nix Store

Never search, grep, or find across `/nix/store`. Resolve an exact source or package path first, then inspect only that path.

For example, from a flake repository, resolve its nixpkgs input with:

```sh
nix eval --impure --raw --expr '(builtins.getFlake (toString ./.)).inputs.nixpkgs.outPath'
```

Other useful sources:

- The exact store paths reported by `nix build --no-link --print-out-paths`.
- A package's `.src` output, if it exposes one.
- An upstream checkout through the `browse-repos` skill.

## Browser Automation

Do not launch or control a browser unless I explicitly request browser automation for the current task, for example with `/skill:browser-cli`. A general request to research, inspect, or test a website is not permission. Use Kagi or direct HTTP for ordinary public research.

Prefer browser-cli when I opt in. Do not switch to agent-browser, Playwright, or another browser driver as an implicit fallback. Carry this restriction into worker briefs; delegation does not grant browser permission. Leave unrelated tabs and the user's browser/bridge processes alone.

## Local State

Keep authentication, secrets, sessions, and mutable Pi settings user-owned. Do not copy them into a repository or Nix store derivation. Never print credentials while checking configuration.
