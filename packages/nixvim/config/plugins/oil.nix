{
  plugins.oil = {
    enable = true;
    settings = {
      default_file_explorer = true;
      delete_to_trash = true;
      skip_confirm_for_simple_edits = true;
      view_options = {
        show_hidden = true;
        natural_order = true;
        is_always_hidden = ''
          function(name, _)
            return name == '..' or name == '.git'
          end
        '';
      };
      keymaps = {
        "q" = "actions.close";
      };
    };
  };

  # Oil-specific keymap
  keymaps = [
    {
      mode = "n";
      key = "-";
      action = "<cmd>Oil<CR>";
      options.desc = "Open parent directory";
    }
  ];
}
