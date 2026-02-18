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
pkgs-master.claude-code-bin
