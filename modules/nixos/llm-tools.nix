{ inputs, pkgs, ... }:
let
  llm-agents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
  mics-skills = inputs.mics-skills.packages.${pkgs.stdenv.hostPlatform.system};

  skillPkgs = [
    mics-skills.kagi-search
    mics-skills.browser-cli
  ];

  skills = pkgs.symlinkJoin {
    name = "pi-skills";
    paths = skillPkgs;
  };
in
{
  environment.systemPackages = [
    skills
    llm-agents.claude-code
    llm-agents.pi
    llm-agents.ccusage
    llm-agents.ccusage-pi
    llm-agents.ccusage-codex
    llm-agents.openspec
  ];

  systemd.user.tmpfiles.rules = map (
    pkg: "L+ %h/.pi/agent/skills/${pkg.pname} - - - - ${skills}/share/skills/${pkg.pname}"
  ) skillPkgs;
}
