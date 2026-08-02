{
  bash,
  coreutils,
  gnused,
  niri,
  runCommand,
  util-linux,
}:
runCommand "niri-reload-config-tests"
  {
    nativeBuildInputs = [
      bash
      coreutils
      gnused
      util-linux
    ];
  }
  ''
    ${bash}/bin/bash ${./niri-reload-config-test.sh} ${niri}/bin/niri-reload-config ${niri} ${niri.version}
    touch $out
  ''
