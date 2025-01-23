local M = {}

---W/E motion function
---@param head boolean
local function forward(head)
	local cursor = vim.api.nvim_win_get_cursor(0)
	local line = vim.api.nvim_buf_get_lines(0, cursor[1] - 1, cursor[1], false)[1]
	local right = line:sub(cursor[2] + 1)

	local fallback = head and "W" or "E"

	--[[ if cursor is on %s, %w, or %p ]]
	local i = 0
	for char in right:gmatch(".") do
		i = i + 1

		if char:match("%s") then
			-- jump with W if
			-- * cursor is on a space
			-- * cursor is on a sequence of alphanumerics or punctuations followed by a space
			vim.cmd("normal! " .. fallback)
			return
		end

		if not char:match("%w") and not char:match("%p") then
			if i == 1 then
				-- jump with budoux if cursor is on a multibyte character
				break
			end

			-- jump to the next multibyte character
			-- if cursor is on a sequence of alphanumerics or punctuations followed by a multibyte character
			vim.api.nvim_win_set_cursor(0, { cursor[1], cursor[2] + i - 1 })
			return
		end
	end

	-- [[jump with budoux]]
	-- if there is no break within the sequence of multibyte characters,
	-- jump to the end of the sequence.
	--
	-- Example where `|` is the cursor and `^` is the jump target:
	-- あああa
	-- |     ^
	local model = require("budoux").load_japanese_model()
	-- Segumentation requires characters on the left of the cursor.
	-- TODO:to improve performance, do segmentation within a sentence or between singlebyte characters (%w, %s, %p).
	local segments = model.parse(line)
	local n = 0
	local back_char = 0
	for _, seg in ipairs(segments) do
		local segchars = vim.fn.split(seg, [[\zs]])
		n = n + #seg
		-- TODO: やっぱり次のセグメントの先頭文字分戻らないといけない気がする
		-- じゃないと、セグメント末尾が半角の時に戻る分がたりない
		back_char = head and 0 or #segchars[#segchars]
		-- 「あいうえお」があったら最後の一文字を除く「あいうえ」のバイト長+1をnに加える
		--           ^ここの位置が欲しい
		-- あなたとジャヴァ今すぐダウンロード
		-- W      EW            EW          E
		if n - back_char > cursor[2] then
			break
		end
	end

	local w, s, p, r = right:find("%w"), right:find("%s"), right:find("%p"), #right
	local delta = math.min(w or r, s or r, p or r)

	-- jump to the next segment
	local nmax = cursor[2] + delta - 1
	if n < nmax then
		vim.api.nvim_win_set_cursor(0, { cursor[1], n - back_char })
		return
	end

	-- jump to the next WORD
	if delta == s then
		vim.cmd("normal! " .. fallback)
		return
	end

	-- jump to the next %w or %p or the end of the line
	vim.api.nvim_win_set_cursor(0, { cursor[1], nmax })

	-- jump to next line if cursor is on the last character
	vim.cmd("normal! hl") -- correct cursor position if it is on the middle of a multibyte character
	if vim.api.nvim_win_get_cursor(0)[2] == cursor[2] then
		vim.cmd("normal! " .. fallback)
	end
end

-- あいうえお

function M.W()
	forward(true)
end

function M.E()
	forward(false)
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
