{
  config,
  lib,
  pkgs,
  wlib,
  ...
}:
let
  plugins = pkgs.vimPlugins;
  parsers = pkgs.vimPlugins.nvim-treesitter-parsers;

  grammars = [
    parsers.nix
    parsers.rust
    parsers.go
    parsers.gomod
    parsers.bash
    parsers.lua
    parsers.toml
    parsers.yaml
    parsers.json
    parsers.markdown
    parsers.markdown_inline
    parsers.typescript
    parsers.tsx
    parsers.python
    parsers.qmljs
    parsers.just
    parsers.query
    parsers.vim
    parsers.regex
    parsers.printf
    parsers.comment
    parsers.diff
    parsers.dockerfile
  ];
in
{
  imports = [ wlib.wrapperModules.neovim ];

  # Heavy servers (rust-analyzer, vtsls, pyright, clangd, bashls) come from project devshells; init.lua enables whichever are found.
  options.languageServers = lib.mkEnableOption "the small language servers and formatters on nvim's PATH";

  config = {
    settings = {
      config_directory = "${./config}";
      aliases = [
        "vi"
        "vim"
      ];
    };

    # No plugin needs a remote host; the node one alone is ~180 MiB.
    hosts = {
      node.nvim-host.enable = false;
      python3.nvim-host.enable = false;
      ruby.nvim-host.enable = false;
    };

    specs = {
      plugins = [
        plugins.oil-nvim
        plugins.fzf-lua
        plugins.gitsigns-nvim
        plugins.mini-nvim
        plugins.tokyonight-nvim
        # Only its lsp/*.lua defaults, used by vim.lsp.enable.
        plugins.nvim-lspconfig
      ];
      treesitter = builtins.concatMap (grammar: [
        grammar
        grammar.passthru.associatedQuery
      ]) grammars;
    };

    runtimePkgs = [
      pkgs.fd
      pkgs.fzf
      pkgs.git
      pkgs.ripgrep
    ]
    ++ lib.optionals config.languageServers [
      pkgs.gopls
      pkgs.lua-language-server
      pkgs.nixd
      pkgs.nixfmt
      pkgs.shellcheck
      pkgs.shfmt
    ];
  };
}
