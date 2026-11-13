{
  nixos =
    { pkgs, self, ... }:
    {
      imports = [ self.modules.nixos.rbw ];

      # `cheat <question>` asks Claude; its key is the vault's anthropic-api-key.
      environment.systemPackages = [ self.packages.${pkgs.stdenv.hostPlatform.system}.cheat ];
    };
}
