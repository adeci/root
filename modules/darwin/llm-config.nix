{
  config,
  inputs,
  lib,
  pkgs,
  self,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  profile = self.packages.${system}.pi-profile;
  mics-skills = inputs.mics-skills.packages.${system};
  user = config.system.primaryUser;
  home = config.users.users.${user}.home;
  searchConfig = (pkgs.formats.json { }).generate "kagi-config.json" {
    password_command = "${pkgs.coreutils}/bin/cat ${config.clan.core.vars.generators.kagi-search.files.session-link.path}";
  };

  skillPkgs = [
    mics-skills.kagi-search
    self.packages.${system}.pexpect-cli
  ];

  skills = pkgs.symlinkJoin {
    name = "pi-skills";
    paths = skillPkgs;
  };
in
{
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
    profile
    skills
    pkgs.pueue
  ];

  # Default queue for pexpect-cli
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
    skills_dir=${lib.escapeShellArg "${home}/.agents/skills"}
    install -d -o ${lib.escapeShellArg user} -g staff "$skills_dir"
    install -d -m 700 -o ${lib.escapeShellArg user} -g staff ${lib.escapeShellArg "${home}/.config/kagi"}
    ln -sfn ${searchConfig} ${lib.escapeShellArg "${home}/.config/kagi/config.json"}
  ''
  + builtins.concatStringsSep "\n" (
    map (pkg: ''
      ln -sfn ${skills}/share/skills/${pkg.pname} "$skills_dir/${pkg.pname}"
    '') skillPkgs
  )
  + ''
    /usr/bin/sudo -H -u ${lib.escapeShellArg user} -- ${profile}/bin/pi-profile-install ${lib.escapeShellArg "${home}/.pi/agent"} \
      || echo "pi-profile: ${home}/.pi/agent left unchanged" >&2
  '';
}
