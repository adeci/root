{
  perSystem =
    { pkgs, inputs', ... }:
    let
      mac-install = pkgs.writeShellApplication {
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
    in
    {
      # First install of a Mac primed by bootstrap.sh: secrets, first nix-darwin switch, then the System Settings steps the config declares.
      apps.mac-install.program = mac-install;

      # Apps aren't built by `nix flake check`; these keep both scripts under shellcheck.
      checks.mac-install = mac-install;
      checks.mac-bootstrap = pkgs.writeShellApplication {
        name = "mac-bootstrap";
        text = builtins.readFile ./bootstrap.sh;
      };
    };
}
