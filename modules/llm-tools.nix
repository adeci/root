{
  nixos =
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
      imports = [ self.modules.nixos.llm-config ];

      environment.systemPackages = [
        llm-agents.pi
        llm-agents.omp
        llm-agents.codex
        llm-agents.claude-code
        llm-agents.grok
        llm-agents.grok-bot
        llm-agents.openspec
        self.packages.${pkgs.stdenv.hostPlatform.system}.herdr
      ];
    };

  darwin =
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
      imports = [ self.modules.darwin.llm-config ];

      environment.systemPackages = [
        llm-agents.pi
        llm-agents.openspec
        llm-agents.workmux
        self.packages.${pkgs.stdenv.hostPlatform.system}.herdr
      ];
    };
}
