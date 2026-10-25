# `thaw` for every installed package built with packages/thaw/wrapper.nix:
# system copies in /etc/thaw/<app>/, a manifest for the `thaw` command, and
# the per-session links, made at login.
{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  fromPackages = lib.listToAttrs (
    map (p: lib.nameValuePair p.passthru.thaw.name p.passthru.thaw) (
      builtins.filter (p: p ? passthru.thaw) config.environment.systemPackages
    )
  );
  # Through work/'s relative `root` input, self is <source>/work/..
  repoRoot = toString (/. + builtins.unsafeDiscardStringContext "${self}");
  repoPath =
    path:
    let
      p = toString path;
    in
    if lib.hasPrefix "${repoRoot}/" p then lib.removePrefix "${repoRoot}/" p else null;

  apps = lib.mapAttrs (name: app: {
    inherit (app) reload optional;
    files = lib.mapAttrs (_: f: f.source) app.files // config.thaw.apps.${name}.files or { };
  }) fromPackages;

  checks = lib.concatLists (
    lib.mapAttrsToList (
      name: app:
      let
        extra = config.thaw.apps.${name}.files or { };
      in
      lib.mapAttrsToList (file: _: {
        assertion = builtins.elem file app.optional;
        message = "thaw.apps.${name}.files.\"${file}\": ${name} accepts ${
          lib.concatStringsSep ", " (map (f: "\"${f}\"") app.optional)
        } here (see its thaw.optional).";
      }) extra
      ++ lib.mapAttrsToList (file: source: {
        assertion = repoPath source != null || extra ? ${file};
        message = "thaw: ${name}'s \"${file}\" must be a file in this repo (e.g. ./${file}), got ${toString source}.";
      }) app.files
      ++ lib.mapAttrsToList (file: source: {
        assertion = repoPath source == null || !lib.hasInfix "/nix/store/" (builtins.readFile source);
        message = "thaw: ${name}'s \"${file}\" contains a /nix/store path; pass it from Nix instead (the file is edited when thawed).";
      }) app.files
    ) apps
  );
in
{
  options.thaw.apps = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options.files = lib.mkOption {
          type = lib.types.attrsOf lib.types.path;
          default = { };
          description = "This machine's files for the app, e.g. its niri.kdl.";
        };
      }
    );
    default = { };
  };

  config = {
    environment.systemPackages = [ self.packages.${pkgs.stdenv.hostPlatform.system}.thaw ];

    assertions =
      checks
      ++ map (name: {
        assertion = fromPackages ? ${name};
        message = "thaw.apps.${name}: no installed package opts into thaw as \"${name}\".";
      }) (builtins.attrNames config.thaw.apps);

    # Machine files outside the repo (generated ones) stay on the system copy
    # even when the app is thawed.
    warnings = lib.concatLists (
      lib.mapAttrsToList (
        name: _app:
        lib.mapAttrsToList (file: _: "thaw: ${name}'s \"${file}\" is not in the repo, so it stays pure.") (
          lib.filterAttrs (_: s: repoPath s == null) (config.thaw.apps.${name}.files or { })
        )
      ) apps
    );

    environment.etc = lib.mkMerge (
      lib.mapAttrsToList (
        name: app:
        lib.mapAttrs' (file: source: lib.nameValuePair "thaw/${name}/${file}" { inherit source; }) app.files
        // {
          "thaw/${name}.json".text = builtins.toJSON {
            inherit (app) reload;
            files = lib.mapAttrs (file: source: {
              pure = "/etc/thaw/${name}/${file}";
              repo = repoPath source;
            }) app.files;
          };
        }
      ) apps
      ++ [
        {
          # The session's links, made at login. `L` never replaces an existing
          # link, so a thawed app stays thawed across a new login. Not through
          # `systemd.user.tmpfiles`: that goes via systemPackages, which `apps`
          # is computed from.
          "xdg/user-tmpfiles.d/thaw.conf".text = lib.concatLines (
            lib.concatLists (
              lib.mapAttrsToList (
                name: app:
                [ "d %t/thaw/${name} 0700 - - -" ]
                ++ map (file: "L %t/thaw/${name}/${file} - - - - /etc/thaw/${name}/${file}") (
                  builtins.attrNames app.files
                )
              ) apps
            )
          );
        }
      ]
    );
  };
}
