# Standalone home-manager configurations for non-NixOS/non-Darwin machines.
# For Clan-managed machines, HM is configured via per-machine home.nix instead.
{ inputs, self, ... }:
{
  flake.homeConfigurations = builtins.listToAttrs (
    map
      (
        system:
        let
          pkgs = import inputs.nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
        in
        {
          name = "alex-${system}";
          value = inputs.home-manager.lib.homeManagerConfiguration {
            inherit pkgs;
            extraSpecialArgs = { inherit inputs self; };
            modules = [
              inputs.noctalia-shell.homeModules.default
              (import ../profiles/home-manager/base.nix)
              {
                home.username = "alex";
                home.homeDirectory = if pkgs.stdenv.isDarwin then "/Users/alex" else "/home/alex";
                home.stateVersion = "25.11";
              }
            ];
          };
        }
      )
      [
        "x86_64-linux"
        "aarch64-darwin"
      ]
  );
}
