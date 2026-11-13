{
  python3Packages,
  runCommand,
  writers,
}:
let
  bin = writers.writePython3Bin "kagi-search" {
    libraries = [ python3Packages.beautifulsoup4 ];
    flakeIgnore = [ "E501" ];
  } (builtins.readFile ./kagi_search.py);
in
runCommand "kagi-search" { meta.mainProgram = "kagi-search"; } ''
  install -Dm755 ${bin}/bin/kagi-search $out/bin/kagi-search
  install -Dm644 ${./SKILL.md} $out/share/skills/kagi-search/SKILL.md
''
