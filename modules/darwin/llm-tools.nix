{ inputs, pkgs, ... }:
let
  llm-agents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  imports = [ ./llm-config.nix ];

  environment.systemPackages = [
    llm-agents.pi
    llm-agents.openspec
    llm-agents.workmux
  ];
}
