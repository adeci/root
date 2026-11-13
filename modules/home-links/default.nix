let
  shared =
    { lib, ... }:
    {
      # Stale links stay behind when an entry goes away.
      options.home.links = lib.mkOption {
        type = lib.types.attrsOf lib.types.pathInStore;
        default = { };
        example = lib.literalExpression ''{ ".config/foo/config.toml" = fooConfig; }'';
        description = "Store paths to link into the primary user's home, keyed by path relative to it.";
      };
    };
in
{
  nixos =
    {
      config,
      lib,
      self,
      ...
    }:
    {
      imports = [
        self.modules.nixos.primary-user
        shared
      ];

      systemd.user.tmpfiles.users.${config.system.primaryUser}.rules = lib.mapAttrsToList (
        path: target: "L+ %h/${path} - - - - ${target}"
      ) config.home.links;
    };

  darwin =
    {
      config,
      lib,
      pkgs,
      self,
      ...
    }:
    let
      user = config.system.primaryUser;
      home = config.system.primaryUserHome;
      homeLink = pkgs.writeShellApplication {
        name = "home-link";
        text = builtins.readFile ./link.sh;
      };
    in
    {
      imports = [
        self.modules.darwin.primary-user
        shared
      ];

      system.activationScripts.postActivation.text = lib.concatStrings (
        lib.mapAttrsToList (path: target: ''
          ${lib.getExe homeLink} ${
            lib.escapeShellArgs [
              user
              target
              "${home}/${path}"
            ]
          }
        '') config.home.links
      );
    };
}
