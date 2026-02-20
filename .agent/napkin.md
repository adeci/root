# Napkin

## Corrections

| Date       | Source | What Went Wrong                                         | What To Do Instead                                                                                                      |
| ---------- | ------ | ------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| 2026-02-20 | self   | Copied extensions directly to ~/.pi/agent/ as raw files | Everything in ~/.pi/agent/ is symlinked from home-manager. Put files in modules/home-manager/pi/ and update default.nix |
| 2026-02-20 | user   | Didn't read root-repo skill before placing files        | ALWAYS read root-repo SKILL.md when touching anything in the repo — it tells you exactly where things go                |

## User Preferences

- Likes to review things before committing — show diffs, describe changes
- ALWAYS read the `root-repo` skill before touching ANY file in this repo
- ALWAYS read the `napkin` skill and this file before doing anything else
- When the task involves pi skills/extensions/prompts/agents, read root-repo FIRST — it tells you exactly where files go

## Patterns That Work

- Yoinked extensions from pi-mono examples — copy files directly, keep enhanced local versions
- summarize.ts has hardcoded model (gpt-5.2) — user may want to change

## Patterns That Don't Work

- (accumulate here)

## Domain Notes

- Root repo is NixOS infra, but pi agent config lives in `~/.pi/agent/`
- Extensions are standalone .ts files or directories with index.ts
