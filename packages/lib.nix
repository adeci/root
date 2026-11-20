{ makeWrapper, symlinkJoin }:
{
  # Electron can't find the keyring on tiling WMs; wrapping keeps the cached build.
  withLibsecret =
    app:
    let
      exe = app.meta.mainProgram;
    in
    symlinkJoin {
      inherit (app) pname version;
      paths = [ app ];
      nativeBuildInputs = [ makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/${exe} --add-flags "--password-store=gnome-libsecret"

        # Exec the wrapper by absolute path, not whatever is on PATH.
        for entry in ${app}/share/applications/*.desktop; do
          target=$out/share/applications/$(basename "$entry")
          rm "$target"
          substitute "$entry" "$target" --replace-fail "Exec=${exe}" "Exec=$out/bin/${exe}"
        done
      '';
      meta = app.meta // {
        platforms = [ "x86_64-linux" ];
      };
    };
}
