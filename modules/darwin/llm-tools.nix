{
  inputs,
  pkgs,
  self,
  ...
}:
let
  llm-agents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  imports = [ ./llm-config.nix ];

  environment.systemPackages = [
    llm-agents.pi
    llm-agents.openspec
    llm-agents.workmux
    self.packages.${pkgs.stdenv.hostPlatform.system}.herdr
  ];
}
