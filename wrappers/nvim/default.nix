{
  config,
  lib,
  pkgs,
  wlib,
  ...
}:
let
  grammars = with pkgs.vimPlugins.nvim-treesitter-parsers; [
    nix
    rust
    go
    gomod
    bash
    lua
    toml
    yaml
    json
    markdown
    markdown_inline
    typescript
    tsx
    python
    qmljs
    just
    query
    vim
    regex
    printf
    comment
    diff
    dockerfile
  ];
in
{
  imports = [ wlib.wrapperModules.neovim ];

  options.languageServers = lib.mkEnableOption ''
    the small language servers and formatters on nvim's PATH. Heavy servers
    (rust-analyzer, vtsls, pyright, clangd, bashls) come from project
    devshells; init.lua enables whichever are found
  '';

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

    specs = with pkgs.vimPlugins; {
      plugins = [
        oil-nvim
        fzf-lua
        gitsigns-nvim
        mini-nvim
        tokyonight-nvim
        # Only its lsp/*.lua defaults, used by vim.lsp.enable.
        nvim-lspconfig
      ];
      treesitter = builtins.concatMap (g: [
        g
        g.passthru.associatedQuery
      ]) grammars;
    };

    runtimePkgs =
      with pkgs;
      [
        fd
        fzf
        git
        ripgrep
      ]
      ++ lib.optionals config.languageServers [
        gopls
        lua-language-server
        nixd
        nixfmt
        shellcheck
        shfmt
      ];
  };
}
