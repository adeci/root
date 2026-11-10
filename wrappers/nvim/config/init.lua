-- LSP maps are the 0.12 defaults: grn gra grr gri grt grx gO K [d ]d gK i_CTRL-S.

vim.g.mapleader = " "

local opt = vim.opt

opt.number = true
opt.relativenumber = true
opt.mouse = "a"
opt.cursorline = true
opt.signcolumn = "yes"
opt.winborder = "rounded"
opt.termguicolors = true
opt.clipboard = "unnamedplus"
opt.showmode = false
opt.showtabline = 0
opt.shortmess:append("I")

opt.tabstop = 2
opt.shiftwidth = 2
opt.expandtab = true
opt.smartindent = true

opt.ignorecase = true
opt.smartcase = true

opt.list = true
opt.listchars = {
	tab = "→ ",
	trail = "·",
	nbsp = "␣",
}

-- Completion: builtin fuzzy popup, fed by LSP (see LspAttach below).
opt.autocomplete = true
opt.completeopt = { "menu", "popup", "fuzzy" }

vim.diagnostic.config({
	virtual_lines = true,
	underline = true,
	update_in_insert = false,
	severity_sort = true,
	signs = {
		text = {
			[vim.diagnostic.severity.ERROR] = "✘",
			[vim.diagnostic.severity.WARN] = "▲",
			[vim.diagnostic.severity.HINT] = "⚑",
			[vim.diagnostic.severity.INFO] = "·",
		},
	},
})

-- Servers not on PATH (e.g. only in some project's devshell) are skipped.
vim.lsp.enable({
	"nixd",
	"rust_analyzer",
	"gopls",
	"lua_ls",
	"bashls",
	"pyright",
	"vtsls",
	"clangd",
	"ruby_lsp",
	"qmlls",
})

vim.api.nvim_create_autocmd("LspAttach", {
	desc = "Enable autotriggered LSP completion",
	callback = function(args)
		local client = vim.lsp.get_client_by_id(args.data.client_id)
		if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_completion) then
			vim.lsp.completion.enable(true, client.id, args.buf, { autotrigger = true })
		end
	end,
})

vim.api.nvim_create_autocmd("FileType", {
	desc = "Start treesitter highlighting when a parser is available",
	callback = function(args)
		pcall(vim.treesitter.start, args.buf)
	end,
})

local map = vim.keymap.set

map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlight" })
map("n", "-", "<cmd>Oil<CR>", { desc = "Open parent directory" })

map("n", "<leader>bd", "<cmd>bdelete<CR>", { desc = "Delete buffer" })
map("n", "<leader>bn", "<cmd>bnext<CR>", { desc = "Next buffer" })
map("n", "<leader>bp", "<cmd>bprevious<CR>", { desc = "Previous buffer" })
