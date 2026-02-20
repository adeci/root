---
name: nix-prefetch-sri
description: Get SRI hashes for URLs and Git repos. Use when adding fetchurl, fetchFromGitHub, or other fetch expressions to Nix code.
---

# Nix Prefetch SRI

Compute SRI hashes for use in Nix fetch expressions.

## URL (fetchurl)

```bash
nix-prefetch-url --type sha256 --unpack <url> 2>/dev/null | xargs nix hash convert --hash-algo sha256 --to sri
```

Or for a non-archive URL (no `--unpack`):

```bash
nix-prefetch-url --type sha256 <url> 2>/dev/null | xargs nix hash convert --hash-algo sha256 --to sri
```

## GitHub Archive (fetchFromGitHub)

```bash
nix-prefetch-url --type sha256 --unpack https://github.com/<owner>/<repo>/archive/<rev>.tar.gz 2>/dev/null | xargs nix hash convert --hash-algo sha256 --to sri
```

## Fake Hash Trick

For `fetchFromGitHub` and similar, you can also use the fake hash approach:

1. Set `hash = "";` or `hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";`
2. Run `nix build` — it will fail with the correct hash in the error message
3. Replace with the real hash

## nix flake prefetch

For flake inputs:

```bash
nix flake prefetch github:<owner>/<repo> --json | nix run nixpkgs#jq -- -r '.hash'
```
