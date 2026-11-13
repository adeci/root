{ makeWrapper, symlinkJoin }:
{
  # Electron's keyring detection fails on tiling WMs (niri, sway); wraps the cached app instead of rebuilding it.
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

        # Desktop entries exec the wrapper by absolute path, independent of PATH.
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
