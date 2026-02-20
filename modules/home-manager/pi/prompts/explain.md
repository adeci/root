---
description: Scout code and explain it in plain language
---

Use the subagent tool with the chain parameter to execute this workflow:

1. First, use the "scout" agent to find and read the code relevant to: $@
2. Then, use the "planner" agent to explain what this code does in plain language, using the scout's findings (use {previous} placeholder). The explanation should cover what it does, why it's structured that way, and how the pieces connect. No implementation plan — just explanation.

Execute this as a chain, passing output between steps via {previous}.
