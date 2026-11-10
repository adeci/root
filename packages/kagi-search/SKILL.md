---
name: kagi-search
description: Search the web with Kagi. Prints Kagi's Quick Answer (an AI summary with numbered sources) followed by the top results.
---

# Usage

```bash
kagi-search "what is the capital of France"   # Quick Answer + top 5 results
kagi-search -n 10 "search query"              # more results
kagi-search -j "search query" | jq '.results[0].url'
```

JSON output: `{"quick_answer": "<markdown or null>", "results": [{"title", "url", "snippet"}]}`.
