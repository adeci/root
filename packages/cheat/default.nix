{
  curl,
  jq,
  rbw,
  writeShellApplication,
}:
writeShellApplication {
  name = "cheat";
  runtimeInputs = [
    curl
    jq
    rbw
  ];
  text = builtins.readFile ./cheat.sh;
  meta.platforms = [ "x86_64-linux" ];
}
