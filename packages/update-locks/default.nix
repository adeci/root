{ git, writeShellApplication }:
writeShellApplication {
  name = "update-locks";
  runtimeInputs = [ git ];
  text = builtins.readFile ./update-locks.sh;
}
