{
  config,
  lib,
  osConfig ? null,
  ...
}:
let
  cfg = config.adeci.cheat;
  anthropicKeyPath =
    if
      osConfig != null && osConfig ? clan && osConfig.clan.core.vars.generators ? anthropic-api-key
    then
      osConfig.clan.core.vars.generators.anthropic-api-key.files.api-key.path
    else
      null;
in
{
  options.adeci.cheat.enable = lib.mkEnableOption "cheat command (quick CLI answers via Haiku)";
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = anthropicKeyPath != null;
        message = "adeci.cheat requires adeci.llm-secrets.enable = true on the NixOS side";
      }
    ];
    programs.fish.functions.cheat = ''
      if test (count $argv) -eq 0
        echo "Usage: cheat <question>"
        echo "Example: cheat scp a folder to remote host"
        return 1
      end
      set -l key (cat ${anthropicKeyPath} 2>/dev/null)
      if test -z "$key"
        echo "Error: could not read API key" >&2
        return 1
      end
      set -l query "$argv"
      set -l payload (jq -nc \
        --arg q "$query" \
        '{
          model: "claude-haiku-4-5",
          max_tokens: 256,
          system: "Reply with only the command. Nothing else. No markdown, no code fences, no explanation.",
          messages: [{role: "user", content: $q}]
        }')
      set -l response (curl -s https://api.anthropic.com/v1/messages \
        -H "content-type: application/json" \
        -H "x-api-key: $key" \
        -H "anthropic-version: 2023-06-01" \
        -d "$payload")
      set -l error (echo "$response" | jq -r '.error.message // empty')
      if test -n "$error"
        echo "Error: $error" >&2
        return 1
      end
      echo "$response" | jq -r '.content[0].text'
    '';
  };
}
