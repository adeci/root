# Napkin

## Corrections

| Date       | Source | What Went Wrong                               | What To Do Instead                                                                                        |
| ---------- | ------ | --------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| 2026-02-20 | self   | Copied files directly to ~/.pi/agent/         | ~/.pi/agent/ is symlinked from home-manager. Put files in modules/home-manager/pi/ and update default.nix |
| 2026-02-20 | self   | Placed a plan file in .github/ without asking | Plans/proposals go in plans/. Ask where files should go before creating them.                             |

## Repo-Specific Rules

- ALWAYS read the `root-repo` skill before touching ANY file in this repo
- When the task involves pi agent config, also read `manage-pi` skill
- New top-level files in modules/home-manager/pi/ need explicit entries in default.nix — auto-discovery only handles subdirectories
- Conditional fish functions via `lib.mkIf config.adeci.<module>.enable`

## Domain Notes

- pi agent config source of truth: modules/home-manager/pi/
- Extensions from pi-mono examples can be copied and adapted locally
- summarize.ts extension has hardcoded model (gpt-5.2) — may want to change
