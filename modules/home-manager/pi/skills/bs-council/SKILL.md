---
name: bs-council
description: Run 3 independent ai-sniffer judges in parallel on a piece of text to detect AI writing. Use when asked to check if text sounds like AI, run the bs council, sniff test, etc.
---

# BS Council

Spawn 3 `ai-sniffer` agents in parallel with the same text. Each judge
evaluates independently without seeing the others' responses.

## How to run

Use the subagent tool in parallel mode with 3 identical tasks:

```
subagent parallel:
  - agent: ai-sniffer, task: "Judge this text:\n\n<the text>"
  - agent: ai-sniffer, task: "Judge this text:\n\n<the text>"
  - agent: ai-sniffer, task: "Judge this text:\n\n<the text>"
```

## How to report

After all 3 return, summarize like this:

1. Show each judge's verdict, confidence, and key reasoning (keep it short)
2. Give the final tally (e.g. 2 AI / 1 UNCERTAIN)
3. If any judges flagged specific phrases, call those out as things to fix
4. If all 3 say HUMAN, it's good to go

Keep the summary casual. This is meant to be fun and useful, not formal.
