---
name: kagi-search
description: Search the web using Kagi. Use for web searches, looking up documentation, error messages, or any current information. Provides AI-generated Quick Answer summaries.
---

# Kagi Search

Requires Kagi subscription + session token in `~/.config/kagi/config.json`.

## Install

```bash
nix run github:Mic92/mics-skills#kagi-search -- "query"
```

## Setup

1. Log in to [Kagi](https://kagi.com)
2. Go to Settings → Session Link → generate and copy
3. Create `~/.config/kagi/config.json`:

```json
{
  "session_link": "https://kagi.com/search?token=YOUR_TOKEN"
}
```

## Usage

```bash
kagi-search "what is the capital of France"
kagi-search -j "search query" | jq '.results[0].url'
kagi-search -j "search query" | jq '.quick_answer.markdown'
kagi-search -n 5 "search query"
```

## Output

Results include:

- Quick Answer (AI-generated summary with references)
- Search results with title, URL, and snippet
