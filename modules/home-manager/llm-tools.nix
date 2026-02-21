{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.adeci.llm-tools;
  llm-agents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
  mics-skills = inputs.mics-skills.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  options.adeci.llm-tools.enable = lib.mkEnableOption "LLM tools (claude-code, pi, ccusage)";
  config = lib.mkIf cfg.enable {
    home.packages = [
      llm-agents.claude-code
      llm-agents.pi
      llm-agents.ccusage
      mics-skills.kagi-search
      mics-skills.context7-cli
      mics-skills.browser-cli
      mics-skills.pexpect-cli
      mics-skills.screenshot-cli
    ];
  };
}
