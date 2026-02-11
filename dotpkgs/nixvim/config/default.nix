{
  imports = [
    ./options.nix
    ./plugins/colorscheme.nix
    ./plugins/treesitter.nix
    ./plugins/telescope.nix
    ./plugins/oil.nix
    ./plugins/lsp.nix
    ./plugins/cmp.nix
    ./plugins/comment.nix
    ./plugins/git.nix
    ./plugins/lightline.nix
    ./plugins/which-key.nix
    ./plugins/mini.nix
    ./plugins/sleuth.nix
    ./plugins/wilder.nix
    ./plugins/web-devicons.nix
    ./plugins/yanky.nix
  ];

  globals.mapleader = " ";

  # Global keymaps
  keymaps = [
    {
      mode = "n";
      key = "<Esc>";
      action = "<cmd>nohlsearch<CR>";
      options.desc = "Clear search highlight";
    }

    # Buffer navigation
    {
      mode = "n";
      key = "<leader>bd";
      action = "<cmd>bdelete<CR>";
      options.desc = "Delete buffer";
    }
    {
      mode = "n";
      key = "<leader>bn";
      action = "<cmd>bnext<CR>";
      options.desc = "Next buffer";
    }
    {
      mode = "n";
      key = "<leader>bp";
      action = "<cmd>bprevious<CR>";
      options.desc = "Previous buffer";
    }
  ];
}
