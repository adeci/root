# Emacs with packages from Nix and init.el through thaw: `thaw emacs` points
# it at the checkout, so edits apply with M-x eval-buffer instead of a rebuild.
{
  config,
  lib,
  pkgs,
  wlib,
  ...
}:
let
  # nixpkgs has 0.59; 0.60 adds ghostel-status-next and the status indicator.
  ghostel =
    epkgs:
    epkgs.ghostel.overrideAttrs (
      final: _: {
        version = "0.60.0";
        src = pkgs.fetchFromGitHub {
          owner = "dakra";
          repo = "ghostel";
          tag = "v${final.version}";
          hash = "sha256-k10nzaIHKGvPJoI1KiiDBY6yDTKL2OAXZ1kxx91BB3E=";
        };
        zig = pkgs.zig_0_17;
        zigDeps = final.zig.fetchDeps {
          inherit (final) src pname version;
          fetchAll = true;
          hash = "sha256-Kt3r1B/5kgjMO89gih/87oEtuWmby9NB6oQp5t0vUYw=";
        };
      }
    );

  # Opens zmx sessions in ghostel. Not on MELPA.
  term-sessions =
    epkgs:
    epkgs.melpaBuild {
      pname = "term-sessions";
      version = "0.1.0-unstable-2026-10-20";
      src = pkgs.fetchFromGitHub {
        owner = "ArthurHeymans";
        repo = "emacs-term-sessions";
        rev = "9c5e726dea26765fe409f262d5474ffa7ac6b379";
        hash = "sha256-mRtwBonE7lGDZN1hh/VaX2XU7I5ykdelnujm5lZpxGg=";
      };
    };
in
{
  imports = [
    wlib.wrapperModules.emacs
    ../thaw/wrapper.nix
  ];

  package = if pkgs.stdenv.hostPlatform.isDarwin then pkgs.emacs else pkgs.emacs-pgtk;

  emacsPackages = epkgs: [
    epkgs.consult
    epkgs.doom-themes
    (ghostel epkgs)
    epkgs.magit
    epkgs.marginalia
    epkgs.orderless
    (term-sessions epkgs)
    epkgs.vertico
  ];

  # term-sessions shells out to zmx; consult-ripgrep runs rg. The daemon's
  # PATH is the system profile, not the shell's.
  runtimePkgs = [
    pkgs.ripgrep
    pkgs.zmx
  ];

  # The upstream module picks the binary wrapper, which drops runShell and
  # with it thaw's launcher links.
  wrapperImplementation = lib.mkForce "nix";

  # Writable state (eln-cache, auto-saves, custom.el) stays out of the store.
  userDirectory = "~/.config/emacs/";

  thaw.files."init.el" = ./init.el;

  # The thaw link, or the store copy if it's missing. "${./init.el}" keeps
  # the file in the closure.
  configFile = ''
    ;;; init.el --- Generated loader -*- lexical-binding: t; -*-
    (load (let* ((dir (getenv "${config.thaw.var}"))
                 (thawed (and dir (expand-file-name "init.el" dir))))
            (if (and thawed (file-readable-p thawed)) thawed "${./init.el}"))
          nil 'nomessage)
  '';
}
