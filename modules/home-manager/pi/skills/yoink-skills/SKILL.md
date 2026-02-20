---
name: yoink-skills
description: Scan someone's pi/agent configuration to discover skills, extensions, and prompts, then present a menu to selectively harvest and adapt them. Use when asked to yoink, borrow, scout, or look through someone's config for useful agent capabilities.
---

# Yoink Skills

Scan a repo or agent config, present what's there, and let the user pick
what to harvest.

## Step 1: Locate the Config

The user provides a path or URL. Use `browse-repos` skill for URLs.

Agent configs typically live in:

```bash
<repo>/.pi/agent/            # Pi global config
<repo>/_global/              # Convention some people use
<repo>/modules/**/pi/        # Home-manager managed
<repo>/.claude/skills/       # Claude Code (compatible skills)
```

Scan:

```bash
find <repo> -name "SKILL.md" -not -path "*/.git/*" -not -path "*/node_modules/*"
find <repo> -name "*.ts" -path "*extension*" -not -path "*/.git/*" -not -path "*/node_modules/*"
find <repo> -name "*.md" -path "*prompt*" -not -path "*/.git/*" -not -path "*/node_modules/*"
find <repo> -name "*.md" -path "*agent*" -not -path "*/.git/*" -not -path "*/node_modules/*"
```

## Step 2: Audit

Read each item's frontmatter/header to understand what it does. Categorize:

- **Skills** — read `SKILL.md` frontmatter for name/description, note
  CLI tool and API key dependencies
- **Extensions** — read top comment or first lines, categorize as safety,
  git, UI, workflow, or tools
- **Prompts** — read frontmatter descriptions
- **Agent definitions** — note any role files

## Step 3: Present the Menu

For each item, present:

- Name and one-line description
- Dependencies (CLI tools, API keys, services)
- Compatibility: works as-is / needs adaptation / missing dependencies
- Recommendation: worth it or not, and why

Be opinionated. Flag the most useful ones. If something overlaps with what we
already have, compare and recommend which is better.

Ask the user which ones to harvest.

## Step 4: Harvest

For each selected item:

1. Read the full source
2. Adapt: remove source-specific paths, check dependencies, simplify if needed
3. Place files per the `root-repo` skill (skills, extensions, prompts locations)
4. Run the verification workflow from `root-repo`

## Notes

- Read source before harvesting — don't copy blindly
- Prefer simple adaptations over exact copies
- If a skill needs a CLI tool we don't have, still offer it — might be easy
  to add via nix
- If it overlaps with what we have, compare rather than adding both
