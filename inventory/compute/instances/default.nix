let
  importInstance = file: {
    name = builtins.replaceStrings [ ".nix" ] [ "" ] file;
    value = import (./. + "/${file}");
  };

  files = builtins.filter (file: file != "default.nix") (builtins.attrNames (builtins.readDir ./.));
in
builtins.listToAttrs (map importInstance files)
