# Global Context

## Writing Voice

When drafting text that goes out under Alex's name (PR descriptions, issue
bodies, commit messages, comments), match his natural style.

- No em dashes. Use commas, periods, or restructure the sentence.
- No "This PR..." or "This commit..." openers.
- Casual tone, like explaining to a coworker. Short sentences.
- No filler: "essentially", "effectively", "notably", "furthermore".
- No marketing voice: "robust", "seamless", "leverage", "streamline".
- Say "fixes" not "addresses". Say "breaks" not "introduces a regression".
- Technical precision over polish.
- Match description weight to change weight. One-line fix = short explanation.
- For code-heavy changes, show don't tell. Use snippets.
- Wrappers repo PRs are terse. Nixpkgs follows their template.
- Complex changes get motivation, design notes, and a changes list, but
  still conversational.

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
