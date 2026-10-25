local fzf = require("fzf-lua")

fzf.setup({
	defaults = {
		winblend = 0,
	},
})

fzf.register_ui_select()

local map = vim.keymap.set
local pickers = {
	["<leader><leader>"] = { "buffers", "Search buffers" },
	["<leader>sf"] = { "files", "Search files" },
	["<leader>sg"] = { "live_grep", "Search by grep" },
	["<leader>sh"] = { "helptags", "Search help" },
	["<leader>sk"] = { "keymaps", "Search keymaps" },
	["<leader>sd"] = { "diagnostics_workspace", "Search diagnostics" },
	["<leader>sr"] = { "resume", "Resume last search" },
	["<leader>s."] = { "oldfiles", "Search recent files" },
}
for keys, picker in pairs(pickers) do
	map("n", keys, function()
		fzf[picker[1]]()
	end, { desc = picker[2] })
end
