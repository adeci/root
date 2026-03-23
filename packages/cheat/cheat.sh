#!/usr/bin/env bash
# cheat — ask Claude for a command, get just the command back.

if [[ $# -eq 0 ]]; then
  echo "Usage: cheat <question>"
  echo "Example: cheat scp a folder to remote host"
  exit 1
fi

key=$(rbw get anthropic-api-key 2>/dev/null) || {
  echo "Error: could not get API key from rbw" >&2
  exit 1
}

query="$*"
payload=$(jq -nc \
  --arg q "$query" \
  '{
    model: "claude-haiku-4-5",
    max_tokens: 256,
    system: "Reply with only the command. Nothing else. No markdown, no code fences, no explanation.",
    messages: [{role: "user", content: $q}]
  }')

response=$(curl -s https://api.anthropic.com/v1/messages \
  -H "content-type: application/json" \
  -H "x-api-key: $key" \
  -H "anthropic-version: 2023-06-01" \
  -d "$payload")

error=$(echo "$response" | jq -r '.error.message // empty')
if [[ -n "$error" ]]; then
  echo "Error: $error" >&2
  exit 1
fi

echo "$response" | jq -r '.content[0].text'
