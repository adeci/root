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

      wrappers.herdr.enable = true;

      environment.systemPackages = [
        llm-agents.pi
        llm-agents.omp
        llm-agents.codex
        llm-agents.claude-code
        llm-agents.grok
        llm-agents.grok-bot
        llm-agents.openspec
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

      wrappers.herdr.enable = true;

      environment.systemPackages = [
        llm-agents.pi
        llm-agents.openspec
        llm-agents.workmux
      ];
    };
}
