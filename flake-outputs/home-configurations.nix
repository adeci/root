{ inputs, ... }:
{
  flake.homeConfigurations.alex = inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = import inputs.nixpkgs {
      system = "x86_64-linux";
      config.allowUnfree = true;
    };
    extraSpecialArgs = {
      inherit inputs;
    };
    modules = [
      ../home-manager/profiles/base.nix
      ../home-manager/profiles/shell.nix
      ../home-manager/profiles/dev.nix
      {
        home.username = "alex";
        home.homeDirectory = "/home/alex";
        home.stateVersion = "24.11";
      }
    ];
  };
}
