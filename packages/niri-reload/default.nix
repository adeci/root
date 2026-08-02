{
  lib,
  self',
  symlinkJoin,
  ...
}:
symlinkJoin {
  name = "niri-reload";
  paths = [ ];
  postBuild = ''
    mkdir -p "$out/bin"
    ln -s ${self'.packages.niri}/bin/niri-reload-config "$out/bin/niri-reload"
  '';
  meta = {
    description = "Reload the niri config from this checkout";
    mainProgram = "niri-reload";
    platforms = lib.platforms.linux;
  };
}
