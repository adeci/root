{
  gcc,
  makeWrapper,
  prusa-slicer,
  runCommand,
  symlinkJoin,
}:
let
  # WebKit gamepads use hidapi, whose hid_get_device_info() returns 0x31 on some devices.
  hidapi-fix = runCommand "hidapi-fix" { nativeBuildInputs = [ gcc ]; } ''
    mkdir -p $out/lib
    gcc -shared -fPIC -o $out/lib/hidapi-fix.so ${./hidapi-fix.c} -ldl
  '';
in
symlinkJoin {
  name = "prusa-slicer-wrapped";
  paths = [ prusa-slicer ];
  nativeBuildInputs = [ makeWrapper ];
  postBuild = ''
    wrapProgram $out/bin/prusa-slicer \
      --set LD_PRELOAD ${hidapi-fix}/lib/hidapi-fix.so
  '';
  meta.platforms = [ "x86_64-linux" ];
}
