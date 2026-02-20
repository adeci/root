---
name: browse-repos
description: Clone and browse GitHub repositories locally for fast file access. Use when exploring external codebases, reading upstream source code, referencing other projects, or when asked to look at a repo or GitHub URL. Always prefer local clones over fetching raw files from GitHub.
---

# Browse Repos

Clone repositories to `$HOME/git/pi-repos/` for fast local file access instead
of making many slow HTTP requests to GitHub's raw content API.

## Workflow

### 1. Check if already cloned

Before cloning, check if the repo already exists locally:

```bash
ls $HOME/git/pi-repos/<owner>--<repo> 2>/dev/null
```

The naming convention is `owner--repo` (double dash separating owner and repo).

### 2. If already cloned, pull latest

```bash
cd $HOME/git/pi-repos/<owner>--<repo> && git pull --ff-only
```

If `git pull` fails (e.g., diverged history), just do a fresh clone:

```bash
rm -rf $HOME/git/pi-repos/<owner>--<repo>
```

Then proceed to step 3.

### 3. Clone if not present

```bash
git clone --depth 1 https://github.com/<owner>/<repo>.git $HOME/git/pi-repos/<owner>--<repo>
```

Use `--depth 1` for shallow clones by default — we usually just need the
latest files. If history is needed (e.g., for `git log`), clone without
`--depth`:

```bash
git clone https://github.com/<owner>/<repo>.git $HOME/git/pi-repos/<owner>--<repo>
```

### 4. Browse freely

Once cloned, use normal file operations:

```bash
# List structure
find $HOME/git/pi-repos/<owner>--<repo> -type f -name "*.nix" | head -20

# Read files
# (use the read tool directly on the local path)

# Search
grep -r "pattern" $HOME/git/pi-repos/<owner>--<repo>/src/
```

## URL Parsing

When given a GitHub URL, extract owner and repo:

| URL                                                  | Owner      | Repo    | Local Path                              |
| ---------------------------------------------------- | ---------- | ------- | --------------------------------------- |
| `https://github.com/NixOS/nixpkgs`                   | NixOS      | nixpkgs | `$HOME/git/pi-repos/NixOS--nixpkgs`     |
| `github:badlogic/pi-mono`                            | badlogic   | pi-mono | `$HOME/git/pi-repos/badlogic--pi-mono`  |
| `https://github.com/anthropics/skills/tree/main/pdf` | anthropics | skills  | `$HOME/git/pi-repos/anthropics--skills` |

For URLs pointing to a specific file or directory, clone the whole repo and
then navigate to that path locally.

## Non-GitHub Repos

For non-GitHub repos (GitLab, Codeberg, etc.), use the same pattern with the
full domain in the directory name:

```bash
git clone --depth 1 https://codeberg.org/owner/repo.git $HOME/git/pi-repos/codeberg.org--owner--repo
```

## Housekeeping

The `$HOME/git/pi-repos/` directory is fully agent-managed. Feel free to:

- Delete old clones that are no longer needed
- Re-clone if something gets corrupted
- Check disk usage with `du -sh $HOME/git/pi-repos/*`

## Important

- **Always prefer local clones over HTTP fetches.** Reading files locally is
  orders of magnitude faster and doesn't hit rate limits.
- **Shallow clone by default.** Only full-clone when you need git history.
- **Pull before reading** if the repo was cloned in a previous session — it
  may be stale.
- **Don't clone enormous monorepos** (like nixpkgs) unless specifically needed.
  For nixpkgs, prefer `nix search` or the online search at search.nixos.org.
