{
  # cheat — ask Claude for a command, get just the command back.
  # Requires rbw with an "anthropic-api-key" entry.
  nixos =
    { pkgs, self, ... }:
    {
      environment.systemPackages = [
        self.packages.${pkgs.stdenv.hostPlatform.system}.cheat
      ];
    };
}
