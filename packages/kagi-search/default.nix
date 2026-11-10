{ pkgs, ... }:
let
  bin = pkgs.writers.writePython3Bin "kagi-search" {
    libraries = [ pkgs.python3Packages.beautifulsoup4 ];
    flakeIgnore = [ "E501" ];
  } (builtins.readFile ./kagi_search.py);
in
pkgs.runCommand "kagi-search" { meta.mainProgram = "kagi-search"; } ''
  install -Dm755 ${bin}/bin/kagi-search $out/bin/kagi-search
  install -Dm644 ${./SKILL.md} $out/share/skills/kagi-search/SKILL.md
''
