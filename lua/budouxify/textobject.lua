local M = {}

local motion = require("budouxify.motion")

---@param opts { inner: boolean, row: number?, col: number?, curline: string?, buf: number?, error_handler?: function }
---@return { start: { row: number, col: number }, finish: { row: number, col: number } } | nil
function M.find(opts)
	local handle_error = opts.error_handler or function(err)
		vim.notify(tostring(err), vim.log.levels.ERROR)
	end
	local ok, row, col = pcall(motion._solve_cursor, opts.row, opts.col)
	if not ok then
		handle_error(tostring(row))
		return nil
	end
	local buf = opts.buf or vim.api.nvim_get_current_buf()
	local curline = opts.curline or vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1]

	for _, word in ipairs(motion._parse_words(curline)) do
		if word.head <= col and col <= word.tail then
			return { start = { row = row, col = word.head }, finish = { row = row, col = word.tail } }
		end
	end
	return nil
end

return M
