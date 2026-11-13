{
  lib,
  gitMinimal,
  openssh,
  python3Packages,
  ruff,
  self,
  stdenv,
}:
python3Packages.buildPythonApplication {
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
  build-system = [ python3Packages.hatchling ];

  nativeCheckInputs = [
    openssh
    ruff
    python3Packages.mypy
    python3Packages.pytestCheckHook
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
      self.packages.${stdenv.hostPlatform.system}.clan-cli
      gitMinimal
      openssh
    ])
  ];

  meta.mainProgram = "mac-install";
}
