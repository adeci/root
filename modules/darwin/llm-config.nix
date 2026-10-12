{
  config,
  inputs,
  pkgs,
  self,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  mics-skills = inputs.mics-skills.packages.${system};
  user = config.system.primaryUser;
  searchConfig = (pkgs.formats.json { }).generate "kagi-config.json" {
    password_command = "${pkgs.coreutils}/bin/cat ${config.clan.core.vars.generators.kagi-search.files.session-link.path}";
  };

  skillPkgs = [
    mics-skills.kagi-search
    self.packages.${system}.browser-cli
    self.packages.${system}.pexpect-cli
  ];

  skills = pkgs.symlinkJoin {
    name = "pi-skills";
    paths = skillPkgs;
  };
in
{
  imports = [ inputs.pi-kit.darwinModules.default ];

  pi-kit = {
    status.enable = true;
    usage.enable = true;
    ask.enable = true;
    agents.enable = true;
    events.enable = true;
    todos.enable = true;
    handoff.enable = true;
    goal.enable = true;
    director.enable = true;
    jobs = {
      enable = true;
      daemon.enable = true;
    };
  };

  clan.core.vars.generators.kagi-search = {
    share = true;
    files.session-link = {
      secret = true;
      owner = user;
      group = "staff";
      mode = "0400";
    };
    prompts.session-link = {
      description = "Kagi session link or token for kagi-search on AI-tools machines";
      type = "hidden";
      persist = true;
    };
  };

  environment.systemPackages = [
    skills
    pkgs.pueue
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
    install -d -o ${user} -g staff "$skills_dir"
    install -d -m 700 -o ${user} -g staff /Users/${user}/.config/kagi
    ln -sfn ${searchConfig} /Users/${user}/.config/kagi/config.json
  ''
  + builtins.concatStringsSep "\n" (
    map (pkg: ''
      ln -sfn ${skills}/share/skills/${pkg.pname} "$skills_dir/${pkg.pname}"
    '') skillPkgs
  );
}
