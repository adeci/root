# nvim plus the small language servers and formatters. Heavy servers
# (rust-analyzer, vtsls, pyright, clangd, bashls) come from project devshells.
{ pkgs, ... }:
{
  imports = [ ../nvim ];

  runtimePkgs = with pkgs; [
    gopls
    lua-language-server
    nixd
    nixfmt
    shellcheck
    shfmt
  ];
}
