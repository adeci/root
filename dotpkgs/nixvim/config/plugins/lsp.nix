{
  plugins.lsp = {
    enable = true;
    inlayHints = true;

    keymaps = {
      diagnostic = {
        "<leader>e" = "open_float";
        "[d" = "goto_prev";
        "]d" = "goto_next";
      };
      lspBuf = {
        "K" = "hover";
        "gD" = "declaration";
        "gd" = "definition";
        "gr" = "references";
        "gi" = "implementation";
        "gt" = "type_definition";
        "<leader>ca" = "code_action";
        "<leader>rn" = "rename";
      };
    };

    preConfig = ''
      vim.diagnostic.config({
        virtual_text = false,
        severity_sort = true,
        float = {
          border = 'rounded',
          source = 'always',
        },
      })

      vim.lsp.handlers['textDocument/hover'] = vim.lsp.with(
        vim.lsp.handlers.hover,
        {border = 'rounded'}
      )

      vim.lsp.handlers['textDocument/signatureHelp'] = vim.lsp.with(
        vim.lsp.handlers.signature_help,
        {border = 'rounded'}
      )
    '';

    postConfig = ''
      vim.diagnostic.config({
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = "✘",
            [vim.diagnostic.severity.WARN]  = "▲",
            [vim.diagnostic.severity.HINT]  = "⚑",
            [vim.diagnostic.severity.INFO]  = "",
          }
        },
        virtual_text = true,
        underline = true,
        update_in_insert = false,
      })
    '';

    servers = {
      # Nix
      nixd = {
        enable = true;
        # https://github.com/nix-community/nixvim/issues/2390
        extraOptions.offset_encoding = "utf-8";
      };

      # Python
      pyright.enable = true;

      # C/C++
      clangd.enable = true;

      # Bash
      bashls.enable = true;

      # Lua
      lua_ls.enable = true;

      # Ruby
      ruby_lsp.enable = true;
    };
  };

  plugins.lsp-lines.enable = true;

  # Rust is special lol
  plugins.rustaceanvim.enable = true;
}
