# Global Context

## Environment

- Always assume Nix is available. We do things declaratively, not imperatively.
- pi source & docs: `~/git/pi-mono/` — read from here, not the nix store.
- Infrastructure repo: `~/git/root/` — declarative source for all system and
  agent config. When adding config, it goes here.
- Agent-cloned repos go in `~/git/pi-repos/` (owner--repo naming convention).

## Search & Research

- Web search: use Kagi. Library docs: use Context7.
- Prefer cloning source code over web searches for code questions.
- `gh search code "pattern lang:nix"` for finding real-world usage patterns.
