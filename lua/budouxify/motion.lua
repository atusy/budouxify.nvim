local M = {}

---@param opts { row: number?, col: number?, curline: string?, head: boolean }
---@return { row: number, col: number } | nil
M.find_forward = function(opts)
	local row, col = 0, 0 ---@type number, number
	if opts.row and opts.col then
		row, col = opts.row, opts.col
	elseif not opts.row and not opts.col then
		local cursor = vim.api.nvim_win_get_cursor(0)
		row, col = cursor[1], cursor[2]
	else
		error("row and col must be both set or both nil")
	end

	if row == nil or col == nil then
		error("row and col should not be nil")
	end

	local curline = opts.curline or vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]
	local rightchars = string.sub(curline, col + 1) -- including the current char

	-- 行末処理
	if not vim.regex(".."):match_str(rightchars) then
		-- 最終行の行末なら移動しない
		local lastrow = vim.api.nvim_buf_line_count(0)
		if row == lastrow then
			return nil
		end

		-- 次の行があるなら試す
		M.find_forward({ row = row + 1, col = 0, head = opts.head })
	end

	-- カーソル位置が空白文字
	local _, prefix_spaces = string.find(rightchars, "^[%s　]+")
	if prefix_spaces then
		-- W
		if opts.head then
			return { row = row, col = col + prefix_spaces }
		end

		-- E
		local _, prefix = string.find(rightchars, "^[%s　]+[%w%p]+")
		if prefix then
			return { row = row, col = col + prefix - 1 }
		end
	end

	error("Unimplemented")
end

return M
