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
  imports = [
    wlib.wrapperModules.neovim
    ../thaw/wrapper.nix
  ];

  thaw.files.config = ./config;

  # The thaw link, or the store copy if it's missing. "${./config}" keeps the
  # store path's context, so the config stays in the closure.
  settings.config_directory = lib.generators.mkLuaInline ''
    (function()
      local thawed = (os.getenv("${config.thaw.var}") or "") .. "/config"
      if vim.fn.filereadable(thawed .. "/init.lua") == 1 then
        return thawed
      end
      return "${./config}"
    end)()
  '';

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

  # git isn't here: every machine already has it on PATH.
  runtimePkgs = with pkgs; [
    fd
    fzf
    ripgrep
  ];
}
