local M = {}

---@param buf number
---@param row number
---@param head boolean
---@return { row: number, col: number } | nil
function M._find_forward_in_next_line(buf, row, head)
	local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]

	if line == "" then
		return M._find_forward_in_next_line(buf, row + 1, head)
	end

	-- 最終行の行末なら移動しない
	if not line then
		local col2 = vim.regex(".$"):match_str(vim.api.nvim_buf_get_lines(buf, row - 1, row, true)[1])
		local cursor = vim.api.nvim_win_get_cursor(0) -- TODO: カーソル取得しなくても解けるようにしたい
		if cursor[1] == row and cursor[2] ~= col2 then
			return { row = row, col = col2 }
		end
		return nil
	end

	-- 次の行の行頭に行く
	-- * W: 行頭が空白文字以外
	-- * E: 行頭が空白文字以外で次が空白文字
	if not vim.regex("^[[:space:]　]"):match_str(line) and (head or line:find("^[^%s　][%s　]")) then
		return { row = row + 1, col = 0 }
	end

	-- その他
	return M._find_forward({
		buf = buf,
		row = row + 1,
		col = 0,
		curline = line,
		head = head,
	})
end

---@param row number?
---@param col number?
---@return number, number
function M._solve_cursor(row, col)
	if row and col then
		return row, col
	end
	if not row and not col then
		local cursor = vim.api.nvim_win_get_cursor(0)
		return cursor[1], cursor[2]
	end
	error("row and col must be both set or both nil")
end

---@param opts { head: boolean, row: number?, col: number?, curline: string?, buf: number?, error_handler?: function }
---@return { row: number, col: number } | nil
function M.find_forward(opts)
	local handle_error = opts.error_handler or function(err)
		vim.notify(tostring(err), vim.log.levels.ERROR)
	end
	-- setup opts
	local ok, row, col = pcall(M._solve_cursor, opts.row, opts.col)
	if not ok then
		handle_error(tostring(row))
	end
	local buf = opts.buf or vim.api.nvim_get_current_buf()
	local curline = opts.curline or vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1]
	local opts2 = vim.tbl_extend("force", opts, { row = row, col = col, curline = curline, buf = buf })

	-- find jump position
	local ok2, pos = pcall(M._find_forward, opts2)
	if not ok2 then
		handle_error(tostring(pos))
		return nil
	end
	if pos and pos.row == row and pos.col == col then
		handle_error("Unexpected case: cursor is not moved")
		return nil
	end
	return pos
end

---@param opts { row: number, col: number, curline: string, head: boolean, buf: number }
---@return { row: number, col: number } | nil
function M._find_forward(opts)
	---@type fun(string): string[]
	local parse = require("budoux").load_japanese_model().parse

	local row, col, curline = opts.row, opts.col, opts.curline
	local rightchars = string.sub(curline, col + 1) -- including the current char

	-- 行末処理
	if rightchars == "" or not vim.regex(".."):match_str(rightchars) then
		--TODO: implement test
		return M._find_forward_in_next_line(opts.buf, opts.row, opts.head)
	end

	-- カーソル位置が空白文字
	-- NOTE: string.find("  " .. x, "^[%s　]+") は
	-- xがalphanumericか全角文字かで結果が変わるので、vim.regexを使う
	local _, prefix_spaces = vim.regex("^[[:space:]　]\\+"):match_str(rightchars)
	if prefix_spaces then
		if string.find(rightchars, "^[%s　]+$") then
			--TODO: implement test
			return M._find_forward_in_next_line(opts.buf, row, opts.head)
		end

		-- W
		if opts.head then
			return { row = row, col = col + prefix_spaces }
		end

		-- E
		local _, prefix = string.find(rightchars, "^[%s　]+[%w%p]+")
		if prefix then
			return { row = row, col = col + prefix - 1 }
		else
			--   あいうえお
			--   ^cursor E
			local pos_W = M._find_forward({
				buf = opts.buf,
				row = row,
				col = col + prefix_spaces,
				curline = curline,
				head = true,
			})
			if not pos_W or pos_W.row > row then
				local x, _ = vim.regex(".$"):match_str(rightchars)
				return { row = row, col = col + x }
			end

			local pos_E = M._find_forward({
				buf = opts.buf,
				row = row,
				col = col + prefix_spaces,
				curline = curline,
				head = false,
			})
			return pos_E
		end
	end

	-- カーソル位置が単語文字の連続
	if vim.regex("^[[:alnum:][:punct:]]\\+[[:space:]　]"):match_str(rightchars) then
		-- 直後にスペース
		-- カーソルが空白文字にあるとみなして再帰
		local length = #string.match(rightchars, "^[%w%p]+")
		if opts.head or length == 1 then
			return M._find_forward({
				buf = opts.buf,
				row = row,
				col = col + length,
				curline = curline,
				head = opts.head,
			})
		end
		return { row = row, col = col + length - 1 }
	elseif vim.regex("^[[:alnum:][:punct:]]\\+$"):match_str(rightchars) then
		if opts.head then
			return M._find_forward_in_next_line(opts.buf, row, opts.head)
		else
			return { row = row, col = #curline - 1 }
		end
	elseif vim.regex("^[[:alnum:][:punct:]]\\+."):match_str(rightchars) then
		-- 直後に日本語
		-- abc今日は
		-- ^ EW
		--   ^W   E
		local _, length = vim.regex("^[[:alnum:][:punct:]]\\+"):match_str(rightchars)
		if opts.head then
			return { row = row, col = col + length }
		else
			if length == 1 then
				return M._find_forward({
					buf = opts.buf,
					row = row,
					col = col + 1,
					curline = curline,
					head = false,
				})
			end
			return { row = row, col = col + length - 1 }
		end
	end

	do
		local _, width = vim.regex("^."):match_str(rightchars)
		if width <= 1 then
			error("Unhandled 1-byte character: '" .. string.sub(rightchars, 1, width) .. "'")
		end
	end

	-- カーソル位置が日本語
	local pos_next_ascii, _ = vim.regex("[[:alnum:][:punct:]]"):match_str(rightchars)
	local pos_next_space, _ = vim.regex("[[:space:]　]"):match_str(rightchars)
	local rightchars_utf8 = (pos_next_ascii or pos_next_space)
			and string.sub(rightchars, 1, math.min(pos_next_ascii or math.huge, pos_next_space or math.huge))
		or rightchars
	local leftchars = string.sub(curline, 1, col)
	local pos_start_of_non_ascii_segments, _ = vim.regex("[^[:alnum:][:punct:][:space:]]\\+$"):match_str(leftchars)
	local leftchars_utf8 = pos_start_of_non_ascii_segments and string.sub(leftchars, pos_start_of_non_ascii_segments)
		or ""
	local segments = parse(leftchars_utf8 .. rightchars_utf8)
	if #segments <= 1 then
		if pos_next_ascii and (not pos_next_space or pos_next_ascii < pos_next_space) then
			if opts.head then
				return { row = row, col = col + pos_next_ascii }
			else
				local n, m = vim.regex(".[[:alnum:][:punct:]]\\+"):match_str(rightchars)
				if n > 0 then
					return { row = row, col = col + n }
				end
				return { row = row, col = col + m - 1 }
			end
		elseif pos_next_space then
			local i1, i2 = vim.regex("^."):match_str(rightchars)
			if opts.head or (i2 - i1 + 1) == pos_next_space then
				return M._find_forward({
					buf = opts.buf,
					row = row,
					col = col + pos_next_space,
					curline = curline,
					head = opts.head,
				})
			end
			local j1, _ = vim.regex(".$"):match_str(segments[1])
			return { row = row, col = col + j1 }
		else
			if opts.head then
				return M._find_forward_in_next_line(opts.buf, row, opts.head)
			end
			local x, _ = vim.regex(".$"):match_str(rightchars)
			return { row = row, col = col + x }
		end
	end

	local n = #leftchars - #leftchars_utf8
	for i, segment in pairs(segments) do
		n = n + #segment
		if n > col then
			if opts.head then
				if i == #segments and not pos_next_ascii then
					return M._find_forward_in_next_line(opts.buf, row, opts.head)
				end
				return { row = row, col = n }
			else
				local x, y = vim.regex(".$"):match_str(string.sub(curline, 1, n))
				return { row = row, col = n - y + x }
			end
		end
	end

	error(
		"Unexpected case."
			.. " Please report the situation withh following information:"
			.. " parameters, current line, and cursor position"
	)
end

return M
