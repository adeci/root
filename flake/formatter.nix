{ inputs, ... }:
{
  imports = [ inputs.treefmt-nix.flakeModule ];

  perSystem =
    { pkgs, ... }:
    {
      treefmt = {
        projectRootFile = ".git/config";
        programs = {
          shellcheck.enable = true;

          nixfmt = {
            enable = true;
            package = pkgs.nixfmt;
          };
          deadnix.enable = true;
          statix.enable = true;

          prettier = {
            enable = true;
            includes = [
              "*.cjs"
              "*.css"
              "*.html"
              "*.js"
              "*.json"
              "*.json5"
              "*.jsx"
              "*.md"
              "*.mdx"
              "*.mjs"
              "*.scss"
              "*.ts"
              "*.tsx"
              "*.vue"
              "*.yaml"
              "*.yml"
            ];
          };
        };
        settings.global.excludes = [
          "*.png"
          "*.jpeg"
          "*.jpg"
          "*.gitignore"
          ".vscode/*"
          "*.toml"
          "*.clan-flake"
          "*.code-workspace"
          "*.pub"
          "*.typed"
          "*.age"
          "*.list"
          "*.desktop"
        ];
      };
    };
}
