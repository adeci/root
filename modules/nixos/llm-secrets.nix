{
  config,
  lib,
  ...
}:
let
  cfg = config.adeci.llm-secrets;
in
{
  options.adeci.llm-secrets.enable = lib.mkEnableOption "LLM API key secrets via clan vars";
  config = lib.mkIf cfg.enable {
    clan.core.vars.generators.anthropic-api-key = {
      share = true;
      files.api-key = {
        owner = config.adeci.primaryUser;
      };
      prompts.api-key = {
        description = "Anthropic API key";
        type = "hidden";
        persist = true;
      };
      script = ''cat "$prompts"/api-key > "$out"/api-key'';
    };
  };
}
