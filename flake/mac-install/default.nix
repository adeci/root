{
  perSystem =
    { pkgs, inputs', ... }:
    {
      # First install of a Mac primed by bootstrap.sh: secrets, first
      # nix-darwin switch, then the System Settings steps the config declares.
      # Later deploys are plain `clan machines update`.
      packages.mac-install = pkgs.writeShellApplication {
        name = "mac-install";
        runtimeInputs = [
          inputs'.clan-core.packages.clan-cli
          pkgs.gitMinimal
          pkgs.gnutar
          pkgs.jq
          pkgs.openssh
        ];
        text = builtins.readFile ./install.sh;
      };

      # bootstrap.sh runs before Nix exists, fetched raw from GitHub, so only
      # this check keeps it under shellcheck.
      checks.mac-bootstrap = pkgs.writeShellApplication {
        name = "mac-bootstrap";
        text = builtins.readFile ./bootstrap.sh;
      };
    };
}
