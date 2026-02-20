---
description: Review current changes with a reviewer agent
---

Use the subagent tool to dispatch a "reviewer" agent to review the current changes.

The reviewer should:

1. Run `git diff` to see uncommitted changes (and `git diff --staged` for staged changes)
2. Read the modified files for full context
3. Analyze for bugs, security issues, and code quality

Additional context from the user: $@
