# LLM agent tools (claude-code, pi, workmux, etc.) available system-wide.
{ inputs, pkgs, ... }:
let
  llm-agents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
  mics-skills = inputs.mics-skills.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  environment.systemPackages = [
    llm-agents.claude-code
    llm-agents.pi
    llm-agents.ccusage
    llm-agents.ccusage-pi
    llm-agents.workmux
    llm-agents.openspec
    mics-skills.kagi-search
    mics-skills.context7-cli
    mics-skills.browser-cli
    mics-skills.pexpect-cli
    mics-skills.screenshot-cli
  ];
}
