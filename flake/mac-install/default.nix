{ lib, ... }:
{
  perSystem =
    { pkgs, self', ... }:
    let
      python = pkgs.python3Packages;

      mac-install = python.buildPythonApplication {
        pname = "mac-install";
        version = "0.1.0";
        pyproject = true;
        src = lib.fileset.toSource {
          root = ./.;
          fileset = lib.fileset.unions [
            ./pyproject.toml
            ./mac_install
            ./tests
          ];
        };
        build-system = [ python.hatchling ];

        nativeCheckInputs = [
          pkgs.openssh
          pkgs.ruff
          python.mypy
          python.pytestCheckHook
        ];
        preCheck = ''
          ruff format --check
          ruff check
          mypy
        '';

        # nix is the caller's own.
        makeWrapperArgs = [
          "--prefix"
          "PATH"
          ":"
          (lib.makeBinPath [
            self'.packages.clan-cli
            pkgs.gitMinimal
            pkgs.openssh
          ])
        ];

        meta.mainProgram = "mac-install";
      };
    in
    {
      # Installs a Mac primed by bootstrap.sh and walks through the System Settings steps it declares; `settings` covers steps a later deploy adds.
      apps.mac-install.program = mac-install;

      # Apps aren't built by `nix flake check`; this runs the tool's tests, ruff and mypy.
      checks.mac-install = mac-install;
    };
}
