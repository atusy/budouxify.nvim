local M = {}

---@param row number
---@param head boolean
---@return { row: number, col: number } | nil
local function _find_forward_in_next_line(row, head)
	-- 最終行の行末なら移動しない
	local lastrow = vim.api.nvim_buf_line_count(0)
	if row == lastrow then
		return nil
	end

	-- 次の行があるなら試す
	return M.find_forward({
		row = row + 1,
		col = 0,
		head = head,
	})
end

---@param opts { row: number?, col: number?, curline: string?, head: boolean }
---@return { row: number, col: number } | nil
M.find_forward = function(opts)
	---@type fun(string): string[]
	local parse = require("budoux").load_japanese_model().parse

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
	if rightchars == "" or not vim.regex(".."):match_str(rightchars) then
		--TODO: implement test
		return _find_forward_in_next_line(row, opts.head)
	end

	-- カーソル位置が空白文字
	-- NOTE: string.find("  " .. x, "^[%s　]+") は
	-- xがalphanumericか全角文字かで結果が変わるので、vim.regexを使う
	local _, prefix_spaces = vim.regex("^[[:space:]　]\\+"):match_str(rightchars)
	if prefix_spaces then
		if string.find(rightchars, "^[%s　]+$") then
			--TODO: implement test
			return _find_forward_in_next_line(row, opts.head)
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
			local pos_W = M.find_forward({
				row = row,
				col = col + prefix_spaces,
				curline = curline,
				head = true,
			})
			if not pos_W or pos_W.row > row then
				local x, _ = vim.regex(".$"):match_str(rightchars)
				return { row = row, col = col + x }
			end

			local pos_E = M.find_forward({
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
		return M.find_forward({
			row = row,
			col = col + #string.match(rightchars, "^[%w%p]+"),
			curline = curline,
			head = opts.head,
		})
	elseif vim.regex("^[[:alnum:][:punct:]]\\+."):match_str(rightchars) then
		-- 直後に日本語
		if opts.head then
			local _, length = vim.regex("^[[:alnum:][:punct:]]\\+"):match_str(rightchars)
			return { row = row, col = col + length }
		else
			error("Unimplemented")
		end
	end

	do
		local _, width = vim.regex("^."):match_str(rightchars)
		if width <= 1 then
			vim.notify("Unhandled 1-byte character: '" .. string.sub(rightchars, 1, width) .. "'")
			return nil
		end
	end

	-- カーソル位置が日本語
	local pos_next_ascii, _ = vim.regex("[[:alnum:][:punct:][:space:]]"):match_str(rightchars)
	local rightchars_utf8 = pos_next_ascii and string.sub(rightchars, 1, pos_next_ascii) or rightchars
	local leftchars = string.sub(curline, 1, col)
	local pos_start_of_non_ascii_segments, _ = vim.regex("[^[:alnum:][:punct:][:space:]]\\+$"):match_str(leftchars)
	local leftchars_utf8 = pos_start_of_non_ascii_segments and string.sub(leftchars, pos_start_of_non_ascii_segments)
		or ""
	local segments = parse(leftchars_utf8 .. rightchars_utf8)
	if #segments <= 1 then
		if pos_next_ascii then
			if opts.head then
				return { row = row, col = col + pos_next_ascii }
			else
				local n = vim.regex(".[[:alnum:][:punct:][:space:]]"):match_str(rightchars)
				return { row = row, col = col + n }
			end
		else
			return _find_forward_in_next_line(row, opts.head)
		end
	end

	local n = #leftchars - #leftchars_utf8
	for i, segment in pairs(segments) do
		n = n + #segment
		if n > col then
			if opts.head then
				if i == #segments and not pos_next_ascii then
					return _find_forward_in_next_line(row, opts.head)
				end
				return { row = row, col = n }
			else
				local x, y = vim.regex(".$"):match_str(string.sub(curline, 1, n))
				return { row = row, col = n - y + x }
			end
		end
	end

	error("Unimplemented")
end

return M
