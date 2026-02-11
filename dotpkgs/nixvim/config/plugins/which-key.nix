{
  plugins.which-key = {
    enable = true;
    settings = {
      delay = 300; # Show after 300ms
      spec = [
        {
          __unkeyed-1 = "<leader>s";
          group = "Search";
        }
        {
          __unkeyed-1 = "<leader>c";
          group = "Code";
        }
        {
          __unkeyed-1 = "<leader>g";
          group = "Git";
        }
        {
          __unkeyed-1 = "<leader>h";
          group = "Git Hunk";
        }
        {
          __unkeyed-1 = "[";
          group = "Previous";
        }
        {
          __unkeyed-1 = "]";
          group = "Next";
        }
      ];
    };
  };
}
