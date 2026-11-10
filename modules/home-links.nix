let
  # Stale links stay behind when an entry goes away.
  option =
    lib:
    lib.mkOption {
      type = lib.types.attrsOf lib.types.pathInStore;
      default = { };
      example = lib.literalExpression ''{ ".config/foo/config.toml" = fooConfig; }'';
      description = "Store paths to link into the primary user's home, keyed by path relative to it.";
    };
in
{
  nixos =
    { config, lib, ... }:
    {
      options.home.links = option lib;

      config.systemd.user.tmpfiles.rules = lib.mapAttrsToList (
        path: target: "L+ %h/${path} - - - - ${target}"
      ) config.home.links;
    };

  darwin =
    { config, lib, ... }:
    let
      user = config.system.primaryUser;
      home = config.users.users.${user}.home;
      link = path: target: ''
        home_link ${lib.escapeShellArg target} ${lib.escapeShellArg "${home}/${path}"}
      '';
    in
    {
      options.home.links = option lib;

      config.system.activationScripts.postActivation.text = # bash
      ''
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
