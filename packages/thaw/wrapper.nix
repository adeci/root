# Opt an app into `thaw`: it reads `thaw.files` through links in
# $XDG_RUNTIME_DIR/thaw/<name>/, which point at the system copy in
# /etc/thaw/<name>/ until `thaw <name>` points them at editable files.
# On NixOS the links are made at login (modules/nixos/thaw.nix); the launcher
# fills in missing ones and, outside NixOS, keeps them on the current store copy.
{
  config,
  lib,
  self,
  ...
}:
let
  cfg = config.thaw;
  # Missing links are made; store links (no /etc/thaw, e.g. macOS) follow each rebuild.
  link = n: fallback: ''
    case "$(readlink "$d/${n}" 2>/dev/null)" in
      "" | /nix/store/*)
        p=/etc/thaw/${cfg.name}/${n}
        [ -e "$p" ] || p=${fallback}
        ln -sfn "$p" "$d/${n}" ;;
    esac
  '';
in
{
  options.thaw = {
    name = lib.mkOption {
      type = lib.types.str;
      default = config.binName;
    };
    files = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      default = { };
      description = "Config files the app reads, by name: raw files in this repo.";
    };
    optional = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Files a machine may add with `thaw.apps.<name>.files`.";
    };
    reload = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Shell run after a switch, with $THAW_DIR set. null: the app watches its files.";
    };
    var = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "THAW_" + lib.toUpper (lib.replaceStrings [ "-" ] [ "_" ] cfg.name);
      description = "Environment variable holding the links' directory, for configs that need it.";
    };
    dir = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "\${XDG_RUNTIME_DIR:-\${TMPDIR:-/tmp}}/thaw/${cfg.name}";
      description = "The links' directory, as a string for the launcher's shell to expand.";
    };
  };

  config = lib.mkIf (cfg.files != { }) {
    runShell = [
      {
        name = "THAW_LINKS";
        data = ''
          d="${cfg.dir}"
          mkdir -p "$d"
          ${lib.concatStringsSep "\n" (lib.mapAttrsToList link cfg.files)}
          ${lib.concatMapStringsSep "\n" (n: link n "/dev/null") cfg.optional}
          export ${cfg.var}="$d"
        '';
      }
    ];
    passthru.thaw = {
      inherit (cfg) name optional reload;
      files = lib.mapAttrs (_: path: {
        source = path;
        repo = lib.removePrefix "${self}/" (toString path);
      }) cfg.files;
    };
  };
}
