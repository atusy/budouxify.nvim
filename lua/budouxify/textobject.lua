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

	if curline == "" then
		return nil
	end

	-- 空白上のiWは、WORDの間の空白の連続を選択する
	local prev, next = nil, nil
	local words = motion._parse_words(curline)
	for i, word in ipairs(words) do
		if word.head <= col and col <= word.tail then
			if opts.inner then
				return { start = { row = row, col = word.head }, finish = { row = row, col = word.tail } }
			end
			-- aWはWORDと後続の空白を選択する
			local after = words[i + 1]
			local finish = after and M._prev_char(curline, after.head) or word.tail
			return { start = { row = row, col = word.head }, finish = { row = row, col = finish } }
		elseif word.tail < col then
			prev = word
		elseif not next then
			next = word
		end
	end
	local start = prev and M._next_char(curline, prev.tail) or 0
	local finish = next and M._prev_char(curline, next.head) or M._prev_char(curline, #curline)
	return { start = { row = row, col = start }, finish = { row = row, col = finish } }
end

--- Byte offset of the char following the one at `col`.
---@param line string
---@param col number
---@return number
function M._next_char(line, col)
	local _, len = vim.regex("^."):match_str(string.sub(line, col + 1))
	return col + len
end

--- Byte offset of the char preceding the one at `col`.
---@param line string
---@param col number
---@return number
function M._prev_char(line, col)
	local x = vim.regex(".$"):match_str(string.sub(line, 1, col))
	return x
end

return M
