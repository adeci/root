return {
	settings = {
		["rust-analyzer"] = {
			-- Client-side watching: fewer inotify watches on macOS and big workspaces.
			files = { watcher = "client" },
		},
	},
}
