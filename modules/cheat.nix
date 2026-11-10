{
  # Requires rbw with an "anthropic-api-key" entry.
  nixos =
    { pkgs, self, ... }:
    {
      environment.systemPackages = [
        self.packages.${pkgs.stdenv.hostPlatform.system}.cheat
      ];
    };
}
