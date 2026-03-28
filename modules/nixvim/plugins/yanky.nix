{
  plugins = {
    # Yank history management
    yanky = {
      enable = true;
      enableTelescope = true;
    };
  };

  # Keymaps for yanky
  keymaps = [
    {
      mode = "n";
      key = "<leader>sy";
      action = "<cmd>Telescope yank_history<CR>";
      options.desc = "Search yank history";
    }
    {
      mode = "n";
      key = "p";
      action = "<Plug>(YankyPutAfter)";
      options.desc = "Paste after cursor";
    }
    {
      mode = "n";
      key = "P";
      action = "<Plug>(YankyPutBefore)";
      options.desc = "Paste before cursor";
    }
    {
      mode = "n";
      key = "<C-n>";
      action = "<Plug>(YankyCycleForward)";
      options.desc = "Cycle forward through yank history";
    }
    {
      mode = "n";
      key = "<C-p>";
      action = "<Plug>(YankyCycleBackward)";
      options.desc = "Cycle backward through yank history";
    }
  ];
}
