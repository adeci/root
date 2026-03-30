{
  pkgs,
  inputs,
  self,
  ...
}:
{
  nixpkgs.config.allowUnfree = true;
  users.mutableUsers = false;
  users.users.root.openssh.authorizedKeys.keys = self.users.alex.sshKeys;
  networking.networkmanager.enable = true;
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  programs.ssh.extraConfig = ''
    Host *.cymric-daggertooth.ts.net
      ControlMaster auto
      ControlPersist 10m
      ControlPath ~/.ssh/cm-%C

    Host *
      AddKeysToAgent yes
  '';
  nix.settings = {
    http-connections = 64;
    max-substitution-jobs = 64;
    download-buffer-size = 268435456; # 256MB
    fallback = true;
  };
  #programs.fish.enable = true;
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    enableGlobalCompInit = false;
    enableLsColors = false;
    promptInit = "";
  };
  environment.systemPackages = [
    inputs.clan-core.packages.${pkgs.stdenv.hostPlatform.system}.clan-cli
    pkgs.kitty.terminfo
  ];
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };
}
