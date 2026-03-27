{
  opts = {
    number = true;
    relativenumber = true;

    clipboard = "unnamedplus";

    # Visual settings
    mouse = "a";
    cursorline = true;

    # Search
    ignorecase = true;
    smartcase = true;

    # Always show to prevent shifting
    signcolumn = "yes";

    # Statusline and UI settings
    showmode = false;
    showtabline = 0; # Hide tab bar
    shortmess = "atI"; # I = no intro message

    tabstop = 2;
    shiftwidth = 2;
    expandtab = true; # Use spaces instead of tabs
    smartindent = true;

    list = true;
    listchars = {
      tab = "→ "; # Show tabs as arrow followed by spaces
      trail = "·"; # Show trailing spaces as dots
      nbsp = "␣"; # Show non-breaking spaces
    };
  };
}
