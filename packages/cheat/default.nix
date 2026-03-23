{
  lib,
  writeShellApplication,
  curl,
  jq,
  rbw,
  ...
}:
writeShellApplication {
  name = "cheat";

  runtimeInputs = [
    curl
    jq
    rbw
  ];

  text = builtins.readFile ./cheat.sh;

  meta = {
    description = "Ask Claude for a command, get just the command back";
    license = lib.licenses.mit;
    mainProgram = "cheat";
  };
}
