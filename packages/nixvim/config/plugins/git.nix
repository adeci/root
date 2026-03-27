{
  plugins = {
    gitsigns = {
      enable = true;
      settings = {
        signs = {
          add.text = "+";
          change.text = "~";
          delete.text = "_";
          topdelete.text = "‾";
          changedelete.text = "~";
        };
      };
    };

    fugitive.enable = true;
  };

  keymaps = [
    # Navigate git changes
    {
      mode = "n";
      key = "]c";
      action.__raw = ''
        function()
          if vim.wo.diff then
            vim.cmd.normal({']c', bang = true})
          else
            require('gitsigns').nav_hunk('next')
          end
        end
      '';
      options.desc = "Next git change";
    }
    {
      mode = "n";
      key = "[c";
      action.__raw = ''
        function()
          if vim.wo.diff then
            vim.cmd.normal({'[c', bang = true})
          else
            require('gitsigns').nav_hunk('prev')
          end
        end
      '';
      options.desc = "Previous git change";
    }
    {
      mode = "n";
      key = "<leader>hp";
      action.__raw = "require('gitsigns').preview_hunk";
      options.desc = "Preview git change";
    }
  ];
}
