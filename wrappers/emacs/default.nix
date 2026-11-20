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

  config = {
    package = emacsWithPackagesFromUsePackage {
      package = if pkgs.stdenv.hostPlatform.isDarwin then pkgs.emacs else pkgs.emacs-pgtk;
      config = ./init.el;
      defaultInitFile = true;
      # Every use-package form names a package to install, without :ensure.
      alwaysEnsure = true;

      override = final: prev: {
        # nixpkgs has 0.59, which lacks ghostel-status-next and the status indicator.
        ghostel = prev.ghostel.overrideAttrs (
          finalAttrs: _: {
            version = "0.63.0";
            src = pkgs.fetchFromGitHub {
              owner = "dakra";
              repo = "ghostel";
              tag = "v${finalAttrs.version}";
              hash = "sha256-3Mh6UMWbqcsiA9Q6NY0nmH69CXYtzr9vTUyV3nSXGac=";
            };
            zig = pkgs.zig_0_17;
            zigDeps = finalAttrs.zig.fetchDeps {
              inherit (finalAttrs) src pname version;
              fetchAll = true;
              hash = "sha256-X16YfBc8i84G2/Dd7/qPhm0lRMDJDLfWCcLeXymb4yg=";
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

    # For term-sessions (zmx) and consult-ripgrep; the daemon doesn't get the shell's PATH.
    runtimePkgs = [
      pkgs.ripgrep
      pkgs.zmx
    ];

    # Launcher shows only the client, as "Emacs"; filesToExclude can't prune a symlinked dir.
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
  };
}
