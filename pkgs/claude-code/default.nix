{
  inputs,
  pkgs,
  ...
}:
let
  pkgs-master = import inputs.nixpkgs-master {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
in
pkgs.symlinkJoin {
  name = "claude-code-wrapped";
  paths = [ pkgs-master.claude-code-bin ];
  nativeBuildInputs = [ pkgs.makeWrapper ];
  postBuild = ''
    wrapProgram $out/bin/claude \

  '';
}
