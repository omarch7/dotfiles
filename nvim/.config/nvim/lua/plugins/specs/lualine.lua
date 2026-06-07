return {
	{
		"nvim-lualine/lualine.nvim",
		dependencies = {
			"nvim-tree/nvim-web-devicons",
			"chrisgrieser/nvim-recorder",
		},
		opts = {
			options = {
				theme = "auto",
				component_separators = "",
				section_separators = { left = "", right = "" },
			},
			sections = {
				lualine_a = { { "mode", separator = { left = "" }, right_padding = 2 } },
				lualine_y = {
					{
						"progress",
						separator = " ",
						padding = { left = 1, right = 0 },
					},
					{ "location", padding = { left = 0, right = 1 } },
					{
						function()
							return require("recorder").displaySlots()
						end,
					},
				},
				lualine_z = {
					{
						function()
							return require("recorder").recordingStatus()
						end,
					},
					{
						function()
							return " " .. os.date("%R")
						end,
						separator = { right = "" },
					},
				},
			},
		},
	},
}
