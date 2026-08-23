local M = {}

local motion = require("budouxify.motion")

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

--- Range of the blanks between two WORDs, where either may be nil
--- to mean the start or the end of the line.
---@param line string
---@param before { head: number, tail: number } | nil
---@param after { head: number, tail: number } | nil
---@return number, number # start and finish (start of last char)
function M._blanks_between(line, before, after)
	local start = before and M._next_char(line, before.tail) or 0
	local finish = after and M._prev_char(line, after.head) or M._prev_char(line, #line)
	return start, finish
end

---@param opts { row: number, col: number, curline: string, inner: boolean }
---@return { start: { row: number, col: number }, finish: { row: number, col: number } } | nil
function M._find(opts)
	local row, col, line = opts.row, opts.col, opts.curline
	if line == "" then
		return nil
	end

	local words = motion._parse_words(line)
	-- 最初の、カーソル以降に終わるWORD
	local i = #words + 1
	for j, word in ipairs(words) do
		if col <= word.tail then
			i = j
			break
		end
	end
	local word, prev, next = words[i], words[i - 1], words[i + 1]

	local start, finish
	if word and word.head <= col then
		-- カーソルがWORD上
		start, finish = word.head, word.tail
		if not opts.inner then
			-- aWはWORDと後続の空白を選択する
			-- 後続の空白がなければ、代わりに先行する空白を含める
			local _, trailing = M._blanks_between(line, word, next)
			if trailing > word.tail then
				finish = trailing
			else
				start = M._blanks_between(line, prev, word)
			end
		end
	else
		-- カーソルが空白上: iWは空白の連続、aWは空白と後続のWORDを選択する
		start, finish = M._blanks_between(line, prev, word)
		if not opts.inner and word then
			finish = word.tail
		end
	end
	return { start = { row = row, col = start }, finish = { row = row, col = finish } }
end

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

	local ok2, range = pcall(M._find, { row = row, col = col, curline = curline, inner = opts.inner })
	if not ok2 then
		handle_error(tostring(range))
		return nil
	end
	return range
end

--- Visually select the range for use in operator-pending and visual mode mappings.
---@param opts { inner: boolean, error_handler?: function }
function M.select(opts)
	local range = M.find(opts)
	if not range then
		return
	end
	-- ビジュアルモードなら一旦抜けてから選択し直す
	if vim.fn.mode():match("^[vV\22]") then
		vim.cmd("normal! \27")
	end
	vim.api.nvim_win_set_cursor(0, { range.start.row, range.start.col })
	vim.cmd("normal! v")
	vim.api.nvim_win_set_cursor(0, { range.finish.row, range.finish.col })
end

return M
