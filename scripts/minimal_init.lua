-- Add current directory to 'runtimepath' to be able to use 'lua' files
vim.cmd([[let &rtp.=','.getcwd()]])

-- Set up test environment when calling headless Neovim (like with `make test`)
if #vim.api.nvim_list_uis() == 0 then
	vim.cmd("set rtp+=deps/mini.nvim")
	vim.cmd("set rtp+=deps/budoux.lua")
	vim.cmd("set rtp+=.")

	-- Set up 'mini.test'
	require("mini.test").setup()
end
