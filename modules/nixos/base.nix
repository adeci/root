{
  pkgs,
  ...
}:
{
  imports = [
    ./leviathan-cache.nix
    ./numtide-cache.nix
  ];

  nixpkgs.config.allowUnfree = true;
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };
  programs.ssh.extraConfig = ''
    Host *
      AddKeysToAgent yes
      CanonicalizeHostname yes
      CanonicalDomains cymric-daggertooth.ts.net adeci
  '';
  nix.settings = {
    http-connections = 64;
    max-substitution-jobs = 64;
    download-buffer-size = 268435456; # 256MB
    fallback = true;
  };
  programs.fish.enable = true;
  environment.systemPackages = [ pkgs.kitty.terminfo ];
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
