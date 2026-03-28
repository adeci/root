{
  plugins.telescope = {
    enable = true;

    settings = {
      defaults = {
        winblend = 0; # Keep window opaque
        borderchars = [
          "─"
          "│"
          "─"
          "│"
          "╭"
          "╮"
          "╯"
          "╰"
        ];
      };
    };

    extensions.fzf-native = {
      enable = true;
    };

    keymaps = {
      "<leader>sf" = {
        action = "find_files";
        options.desc = "Search files";
      };
      "<leader>sg" = {
        action = "live_grep";
        options.desc = "Search by grep";
      };
      "<leader><leader>" = {
        action = "buffers";
        options.desc = "Search buffers";
      };
      "<leader>sh" = {
        action = "help_tags";
        options.desc = "Search help";
      };
      "<leader>sk" = {
        action = "keymaps";
        options.desc = "Search keymaps";
      };
      "<leader>sd" = {
        action = "diagnostics";
        options.desc = "Search diagnostics";
      };
      "<leader>sr" = {
        action = "resume";
        options.desc = "Resume last search";
      };
      "<leader>s." = {
        action = "oldfiles";
        options.desc = "Search recent files";
      };
    };
  };
}
