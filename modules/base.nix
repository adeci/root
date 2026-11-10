let
  # Every machine, Linux or Mac: SSH client, root's keys, editor, clan-cli.
  shared =
    {
      config,
      inputs,
      lib,
      pkgs,
      self,
      ...
    }:
    {
      # Symlinks into the primary user's home, the one thing home-manager did
      # that features still need. Linux makes them with user tmpfiles, macOS at
      # activation. Stale links stay behind when an entry goes away.
      options.home.links = lib.mkOption {
        type = lib.types.attrsOf lib.types.pathInStore;
        default = { };
        example = lib.literalExpression ''{ ".config/foo/config.toml" = fooConfig; }'';
        description = "Store paths to link into the primary user's home, keyed by path relative to it.";
      };

      config = {
        nixpkgs.config.allowUnfree = true;

        # Root accepts the same keys as the machine's primary user.
        users.users.root.openssh.authorizedKeys.keys =
          config.users.users.${self.users.alex.username}.openssh.authorizedKeys.keys;

        environment.variables.EDITOR = "nvim";

        programs.ssh.extraConfig = lib.mkMerge [
          ''
            Host *.cymric-daggertooth.ts.net
              ControlMaster auto
              ControlPersist 10m
              ControlPath ~/.ssh/cm-%C

            # lachesis takes only YubiKey keys.
            Host lachesis lachesis.cymric-daggertooth.ts.net
              IdentityFile ~/.ssh/id_ed25519_sk_spark
              IdentityFile ~/.ssh/id_ed25519_sk_ember
          ''
          # The catch-all goes after every feature's specific Host blocks: ssh
          # takes the first value it finds for each option.
          (lib.mkAfter ''
            Host *
              AddKeysToAgent yes
              SendEnv COLORTERM
          '')
        ];

        environment.systemPackages = [
          inputs.clan-core.packages.${pkgs.stdenv.hostPlatform.system}.clan-cli
        ];
        wrappers.nvim.enable = true;
      };
    };

  nixSettings = {
    http-connections = 64;
    max-substitution-jobs = 64;
    download-buffer-size = 268435456; # 256MB
    fallback = true;
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
        shared
      ];

      users.mutableUsers = false;

      clan.core.networking.forwardAgent = true;

      systemd.user.tmpfiles.rules = lib.mapAttrsToList (
        path: target: "L+ %h/${path} - - - - ${target}"
      ) config.home.links;

      # Secrets go in through a systemd unit that restarts consumers itself;
      # restarts requested from the activation script are deprecated.
      sops.useSystemdActivation = true;

      services.openssh = {
        enable = true;
        settings = {
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
          AcceptEnv = [ "COLORTERM" ];
        };
      };

      nix.settings = nixSettings;
      programs.direnv.enable = true;
      documentation.dev.enable = true;
      documentation.man.cache.enable = true;
      environment.systemPackages = [
        pkgs.kitty.terminfo
        pkgs.man-pages
        pkgs.man-pages-posix
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
    };

  # Every Mac, desktop or headless: nix, accounts, sshd, shell. Desktop
  # settings live in the desktop feature.
  darwin =
    {
      config,
      inputs,
      lib,
      self,
      ...
    }:
    let
      user = self.users.alex.username;
    in
    {
      imports = [
        self.modules.darwin.wrappers
        shared
        inputs.nix-index-database.darwinModules.nix-index
      ];

      nix.enable = true;
      nix.settings = lib.mkIf config.nix.enable (
        nixSettings
        // {
          trusted-users = [
            "root"
            user
          ];
        }
      );

      # nix-index with pre-built database: command-not-found handler + comma
      programs.nix-index-database.comma.enable = true;

      # nix-darwin owns the primary account, so it sets the login shell (no
      # dscl by hand) and its keys. macOS gives the first account uid 501.
      system.primaryUser = user;
      users.knownUsers = [ user ];
      users.users.${user} = {
        uid = lib.mkDefault 501;
        shell = config.wrappers.zsh.wrapper;
      };

      # Keys only, and only the ones declared here (users.users.*.openssh).
      services.openssh = {
        enable = true;
        extraConfig = ''
          PasswordAuthentication no
          KbdInteractiveAuthentication no
          AuthorizedKeysFile none
          AcceptEnv COLORTERM
        '';
      };

      # Wrapped shell and tools
      programs.zsh.enable = true;
      environment.pathsToLink = [ "/share/zsh" ];
      environment.shells = lib.mkDefault [ config.wrappers.zsh.wrapper ];
      wrappers.zsh.enable = true;
      wrappers.git.enable = true;
      wrappers.tmux.enable = true;
      wrappers.btop.enable = true;

      # macOS sshd sets no locale; without this, ssh sessions (and tmux started
      # from them) run in the C locale and mangle non-ASCII/Nerd Font glyphs.
      environment.variables.LANG = "en_US.UTF-8";

      system.activationScripts.postActivation.text =
        let
          home = config.users.users.${user}.home;
          link = path: target: ''
            home_link ${lib.escapeShellArg target} ${lib.escapeShellArg "${home}/${path}"}
          '';
        in
        # bash
        ''
          # Keep Spotlight and fseventsd off the store volume.
          touch /nix/.metadata_never_index
          mkdir -p /nix/.fseventsd
          touch /nix/.fseventsd/no_log

          # home.links, made as the user. A real file in the way stays put.
          home_link() {
            if [[ -e "$2" && ! -L "$2" ]]; then
              echo "home.links: $2 is not a symlink; left alone" >&2
            else
              /usr/bin/sudo -u ${user} -- /bin/mkdir -p "$(/usr/bin/dirname "$2")"
              /usr/bin/sudo -u ${user} -- /bin/ln -sfn "$1" "$2"
            fi
          }
        ''
        + lib.concatStrings (lib.mapAttrsToList link config.home.links);
    };
}
