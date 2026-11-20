let
  shared =
    {
      config,
      lib,
      pkgs,
      self,
      ...
    }:
    {
      nixpkgs.config.allowUnfree = true;

      users.users.root.openssh.authorizedKeys.keys =
        config.users.users.${config.system.primaryUser}.openssh.authorizedKeys.keys;

      environment.variables = {
        EDITOR = "nvim";
        VISUAL = "nvim";
      };

      programs.ssh.extraConfig = lib.mkMerge [
        # Not for root: on a build host, root could reuse connections to deployed machines.
        ''
          Match host *.${config.clan.core.settings.domain} !localuser root
            ControlMaster auto
            ControlPersist 10m
            ControlPath ~/.ssh/cm-%C
        ''
        # Catch-all last: ssh uses the first value it finds per option.
        (lib.mkAfter ''
          Host *
            AddKeysToAgent yes
            SendEnv COLORTERM
        '')
      ];

      environment.systemPackages = [
        self.packages.${pkgs.stdenv.hostPlatform.system}.clan-cli
      ];
      wrappers.nvim.enable = true;
      programs.direnv.enable = true;
      clan.core.networking.forwardAgent = true;
    };

  nixSettings = {
    http-connections = 64;
    max-substitution-jobs = 64;
    download-buffer-size = 268435456; # 256MB
    fallback = true;
    substituters = [
      "https://cache.numtide.com?priority=50"
      "https://nix-community.cachix.org?priority=50"
      "https://cache.clan.lol?priority=50"
    ];
    trusted-public-keys = [
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "cache.clan.lol-1:3KztgSAB5R1M+Dz7vzkBGzXdodizbgLXGXKXlcQLA28="
    ];
  };
in
{
  nixos =
    {
      config,
      lib,
      pkgs,
      self,
      ...
    }:
    {
      imports = [
        self.modules.nixos.wrappers
        self.modules.nixos.home-links
        self.modules.nixos.primary-user
        shared
      ];

      users.mutableUsers = false;
      # Activation-script restarts are deprecated.
      sops.useSystemdActivation = true;
      # Default waits 5 s every boot; 1 s is enough to pick an older generation.
      boot.loader.timeout = lib.mkDefault 1;

      services.openssh = {
        enable = true;
        settings = {
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
          AcceptEnv = [ "COLORTERM" ];
        };
      };

      # Sudo users may use Nix as trusted users; NixOS already trusts root.
      nix.settings = nixSettings // {
        trusted-users = [ "@wheel" ];
      };
      documentation.dev.enable = true;
      documentation.man.cache.enable = true;
      environment.systemPackages = [
        pkgs.kitty.terminfo
        pkgs.man-pages
        pkgs.man-pages-posix
      ];
      # Machines that travel import auto-timezone instead.
      time.timeZone = lib.mkDefault config.system.primaryUserProfile.timeZone;
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
    };

  darwin =
    {
      config,
      lib,
      self,
      ...
    }:
    {
      imports = [
        self.modules.darwin.wrappers
        self.modules.darwin.home-links
        self.modules.darwin.primary-user
        shared
      ];

      nix.enable = true;
      nix.settings = lib.mkIf config.nix.enable (
        nixSettings
        // {
          trusted-users = [
            "root"
            config.system.primaryUser
          ];
        }
      );

      # Only the keys declared in users.users.*.openssh.
      services.openssh = {
        enable = true;
        extraConfig = ''
          PasswordAuthentication no
          KbdInteractiveAuthentication no
          AuthorizedKeysFile none
          AcceptEnv COLORTERM
        '';
      };

      # macOS sshd sets no locale; C locale mangles Nerd Font glyphs over ssh and in tmux.
      environment.variables.LANG = "en_US.UTF-8";

      system.activationScripts.postActivation.text = # bash
        ''
          # Keep Spotlight and fseventsd off the store volume.
          touch /nix/.metadata_never_index
          mkdir -p /nix/.fseventsd
          touch /nix/.fseventsd/no_log
        '';
    };
}
