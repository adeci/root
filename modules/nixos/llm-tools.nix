{
  inputs,
  pkgs,
  self,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  llm-agents = inputs.llm-agents.packages.${system};
  mics-skills = inputs.mics-skills.packages.${system};

  skillPkgs = [
    self.packages.${system}.agent-browser
    mics-skills.kagi-search
    mics-skills.browser-cli
    mics-skills.pexpect-cli
  ];

  skills = pkgs.symlinkJoin {
    name = "pi-skills";
    paths = skillPkgs;
  };
in
{
  environment.systemPackages = [
    skills
    llm-agents.pi
    pkgs.pueue
    llm-agents.openspec
    llm-agents.workmux
  ];

  systemd.user.services.pueued = {
    description = "Pueue task queue daemon";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.pueue}/bin/pueued";
      Restart = "on-failure";
      RestartSec = 1;
    };
  };

  systemd.user.tmpfiles.rules = [
    "d %h/.agents/skills - - - - -"
  ]
  ++ map (pkg: "r %h/.pi/agent/skills/${pkg.pname} - - - - -") skillPkgs
  ++ map (pkg: "r %h/.pi/agent/skills/managed/${pkg.pname} - - - - -") skillPkgs
  ++ [ "r %h/.pi/agent/skills/managed - - - - -" ]
  ++ map (
    pkg: "L+ %h/.agents/skills/${pkg.pname} - - - - ${skills}/share/skills/${pkg.pname}"
  ) skillPkgs;
}
