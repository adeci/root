---
name: context7-cli
description: Fetch up-to-date library documentation from Context7. Use when you need current code examples, API docs, or usage patterns for any library or framework.
---

# Context7 CLI

Look up current library documentation and code examples. Works without an API
key (rate-limited). Optional free key at https://context7.com/dashboard.

## Install

```bash
nix run github:Mic92/mics-skills#context7-cli -- search <library> "query"
```

## Usage

```bash
# Search for libraries
context7-cli search react "how to use hooks"
context7-cli search nixpkgs "fetchFromGitHub"

# Get documentation (use library ID from search results)
context7-cli docs /vercel/next.js "middleware authentication"
context7-cli docs /nixos/nixpkgs "mkDerivation"

# With specific version
context7-cli docs /vercel/next.js/v14.3.0 "app router"

# JSON output for parsing
context7-cli search --json react "hooks" | jq '.results[0].id'
context7-cli docs --json /vercel/next.js "routing"
```

## Setup (optional, for higher rate limits)

Get a free API key at https://context7.com/dashboard, then either:

```bash
export CONTEXT7_API_KEY="ctx7sk_..."
```

Or create `~/.config/context7/config.json`:

```json
{
  "api_key": "ctx7sk_..."
}
```
