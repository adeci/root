{
  # Reads its API key from an "anthropic-api-key" entry in the Bitwarden vault.
  nixos =
    { pkgs, self, ... }:
    {
      environment.systemPackages = [
        self.packages.${pkgs.stdenv.hostPlatform.system}.cheat
      ];
    };
}
