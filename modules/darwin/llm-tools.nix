{
  config,
  inputs,
  pkgs,
  self,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  llm-agents = inputs.llm-agents.packages.${system};
  mics-skills = inputs.mics-skills.packages.${system};
  user = config.system.primaryUser;

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

  launchd.user.agents.pueued.serviceConfig = {
    Label = "org.pueue.pueued";
    ProgramArguments = [ "${pkgs.pueue}/bin/pueued" ];
    RunAtLoad = true;
    KeepAlive = {
      Crashed = true;
      SuccessfulExit = false;
    };
    ProcessType = "Background";
  };

  system.activationScripts.postActivation.text = # bash
  ''
    skills_dir="/Users/${user}/.agents/skills"
    legacy_skills_dir="/Users/${user}/.pi/agent/skills"
    install -d -o ${user} -g staff "$skills_dir"
  ''
  + builtins.concatStringsSep "\n" (
    map (pkg: ''
      if [ -L "$legacy_skills_dir/${pkg.pname}" ]; then
        rm "$legacy_skills_dir/${pkg.pname}"
      fi
      if [ -L "$legacy_skills_dir/managed/${pkg.pname}" ]; then
        rm "$legacy_skills_dir/managed/${pkg.pname}"
      fi
      ln -sfn ${skills}/share/skills/${pkg.pname} "$skills_dir/${pkg.pname}"
    '') skillPkgs
  )
  + ''
    rmdir "$legacy_skills_dir/managed" 2>/dev/null || true
  '';
}
