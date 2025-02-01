local M = {}

---@param segments string[]
---@param column number
---@param head boolean
---@return number
function M._find_jump_pos(segments, column, head)
	local n = 0
	for _, seg in ipairs(segments) do
		n = n + #seg

		-- あいうえお_かきくけこ_さしすせそ_たちつてと
		--                |    E W
		-- `_`をセグメント協会、`|`をカーソル位置とする。
		-- nは行頭からカーソル（`|`）を位置を超える最初のセグメントの右端の文字までのバイト数（「あいうえおかきくけこ」）
		-- nvim_win_set_cursorの列は0-indexedなので、バイト数の合計は実質的に次のセグメントの1文字目の位置で`W`相当になる
		-- また、最後のセグメントの最後の文字「こ」のバイト数をひくと、「あいうえおかきくけ」のバイト数になり、実質的に「こ」の位置を示すので`E`相当になる
		if head then
			if n > column then
				break
			end
		else
			local segchars = vim.fn.split(seg, [[\zs]])
			local lastchar = segchars[#segchars]
			if n - #lastchar > column then
				n = n - #lastchar
				break
			end
		end
	end
	return n
end

---@param head boolean
---@param line string
---@param col number
---@param segmenter function
---@return string | number
function M._forward(head, line, col, segmenter)
	local right = line:sub(col + 1)

	local fallback = head and "W" or "E"

	--[[ if cursor is on %s, %w, or %p ]]
	local i = 0
	for char in right:gmatch(".") do
		i = i + 1

		if char:match("%s") then
			-- jump with W if
			-- * cursor is on a space
			-- * cursor is on a sequence of alphanumerics or punctuations followed by a space
			return fallback
		end

		if not char:match("%w") and not char:match("%p") then
			if i == 1 then
				-- jump with budoux if cursor is on a multibyte character
				break
			end

			-- jump to the next multibyte character
			-- if cursor is on a sequence of alphanumerics or punctuations followed by a multibyte character
			return col + i - 1
		end
	end

	-- [[jump with budoux]]
	-- if there is no break within the sequence of multibyte characters,
	-- jump to the end of the sequence.
	--
	-- Example where `|` is the cursor and `^` is the jump target:
	-- あああa
	-- |     ^

	-- Segmentation requires characters on the left of the cursor.
	-- TODO:to improve performance, do segmentation within a sentence or between singlebyte characters (%w, %s, %p).
	local segments = segmenter(line)
	local n = M._find_jump_pos(segments, col, head)

	local w, s, p, r = right:find("%w"), right:find("%s"), right:find("%p"), #right
	local delta = math.min(w or r, s or r, p or r)

	-- jump to the next segment
	local nmax = col + delta - 1
	if n < nmax then
		return n
	end

	-- jump to the next WORD
	if delta == s then
		return fallback
	end

	-- jump to the next %w or %p or the end of the line
	if delta == w or delta == p then
		return nmax
	end

	-- jump to next line if cursor is on the last character
	if delta == #right then
		if head then
			return fallback
		else
			error("Unimplemented")
		end
	end
	error("Should not be reachable")
end

---W/E motion function
---@param opt {head: boolean, win: number?, segmenter: function?}
function M.forward(opt)
	opt.win = opt.win or vim.api.nvim_get_current_win()
	local buf = vim.api.nvim_win_get_buf(opt.win)
	local cursor = vim.api.nvim_win_get_cursor(opt.win)
	local line = vim.api.nvim_buf_get_lines(buf, cursor[1] - 1, cursor[1], false)[1]
	local target = M._forward(opt.head, line, cursor[2], opt.segmenter or require("budoux").load_japanese_model().parse)
	if type(target) == "string" then
		vim.cmd("normal! " .. target)
	else
		vim.api.nvim_win_set_cursor(opt.win, { cursor[1], target })
	end
end

-- あいうえお

function M.W()
	M.forward({ head = true })
end

function M.E()
	M.forward({ head = false })
end

pcall(vim.keymap.del, { "n", "x", "o" }, "W")
vim.keymap.set({ "n", "x", "o" }, "W", function()
	M.W()
end)
vim.keymap.set({ "n", "x", "o" }, "E", function()
	M.E()
end)
-- あなたとジャヴァ今すぐダウンロード
-- W      EW            EW          E

return M
