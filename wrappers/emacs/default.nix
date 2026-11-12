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

      # Not on MELPA.
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

  # term-sessions shells out to zmx and consult-ripgrep runs rg; the daemon's PATH is the system profile, not the shell's.
  runtimePkgs = [
    pkgs.ripgrep
    pkgs.zmx
  ];

  # The launcher shows only the client, as "Emacs" (it starts a daemon if none runs); share/applications is a single symlink filesToExclude can't prune, so rebuild it.
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
