# Emacs with init.el built in as default.el. Nix installs every package a
# `(use-package NAME ...)` form in init.el names (emacs-overlay's
# emacsWithPackagesFromUsePackage), so adding one there is enough.
# To try edits before a deploy, open this checkout's init.el and run
# M-x eval-buffer.
{
  config,
  inputs,
  pkgs,
  wlib,
  ...
}:
let
  inherit (pkgs.extend inputs.emacs-overlay.overlays.emacs) emacsWithPackagesFromUsePackage;
in
{
  imports = [ wlib.modules.default ];

  package = emacsWithPackagesFromUsePackage {
    package = if pkgs.stdenv.hostPlatform.isDarwin then pkgs.emacs else pkgs.emacs-pgtk;
    config = ./init.el;
    defaultInitFile = true;
    # Every use-package form names a package to install, without :ensure.
    alwaysEnsure = true;

    override = final: prev: {
      # nixpkgs has 0.59; 0.60 adds ghostel-status-next and the status indicator.
      ghostel = prev.ghostel.overrideAttrs (
        self: _: {
          version = "0.60.0";
          src = pkgs.fetchFromGitHub {
            owner = "dakra";
            repo = "ghostel";
            tag = "v${self.version}";
            hash = "sha256-k10nzaIHKGvPJoI1KiiDBY6yDTKL2OAXZ1kxx91BB3E=";
          };
          zig = pkgs.zig_0_17;
          zigDeps = self.zig.fetchDeps {
            inherit (self) src pname version;
            fetchAll = true;
            hash = "sha256-Kt3r1B/5kgjMO89gih/87oEtuWmby9NB6oQp5t0vUYw=";
          };
        }
      );

      # Opens zmx sessions in ghostel. Not on MELPA.
      term-sessions = final.melpaBuild {
        pname = "term-sessions";
        version = "0.1.0-unstable-2026-10-20";
        src = pkgs.fetchFromGitHub {
          owner = "ArthurHeymans";
          repo = "emacs-term-sessions";
          rev = "9c5e726dea26765fe409f262d5474ffa7ac6b379";
          hash = "sha256-mRtwBonE7lGDZN1hh/VaX2XU7I5ykdelnujm5lZpxGg=";
        };
      };
    };
  };

  # term-sessions shells out to zmx; consult-ripgrep runs rg. The daemon's
  # PATH is the system profile, not the shell's.
  runtimePkgs = [
    pkgs.ripgrep
    pkgs.zmx
  ];

  # The launcher shows only the client, as "Emacs": it reaches the daemon
  # and starts one if none is running. Its "New Instance" action still opens
  # a standalone Emacs. share/applications arrives as one symlink into the
  # emacs package, so filesToExclude can't drop entries; rebuild the directory.
  buildCommand.launcherEntries = {
    after = [ "symlinkScript" ];
    data = ''
      apps=${placeholder config.outputName}/share/applications
      src=$(readlink -f "$apps")
      rm "$apps"
      mkdir "$apps"
      for f in "$src"/*.desktop; do
        case "''${f##*/}" in
          emacs.desktop | emacs-mail.desktop) ;;
          emacsclient.desktop)
            ${pkgs.gnused}/bin/sed 's/^Name=Emacs (Client)$/Name=Emacs/' "$f" > "$apps/emacsclient.desktop"
            ;;
          *) ln -s "$f" "$apps/" ;;
        esac
      done
    '';
  };
}
