{ coreutils, writeShellApplication }:
writeShellApplication {
  name = "home-links";
  runtimeInputs = [ coreutils ];
  text = builtins.readFile ./link.sh;
}
