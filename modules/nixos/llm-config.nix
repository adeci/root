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
  user = self.users.alex.username;
  home = config.users.users.${user}.home;
  mics-skills = inputs.mics-skills.packages.${system};
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
  imports = [ inputs.pi-kit.nixosModules.default ];

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
      group = config.users.users.${user}.group;
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

  system.activationScripts.pi-profile = {
    deps = [ "users" ];
    text = ''
      ${pkgs.util-linux}/bin/runuser -u ${lib.escapeShellArg user} -- ${profile}/bin/pi-profile-install ${lib.escapeShellArg "${home}/.pi/agent"}
    '';
  };

  systemd.user.services.pueued = {
    description = "Pueue task queue daemon";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.pueue}/bin/pueued";
      Restart = "on-failure";
      RestartSec = 1;
      UMask = "0077";
    };
  };

  systemd.user.tmpfiles.rules = [
    "d %h/.config/kagi 0700 - - - -"
    "L+ %h/.config/kagi/config.json - - - - ${searchConfig}"
    "d %h/.agents/skills - - - - -"
  ]
  ++ map (
    pkg: "L+ %h/.agents/skills/${pkg.pname} - - - - ${skills}/share/skills/${pkg.pname}"
  ) skillPkgs;
}
