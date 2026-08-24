local M = {}

local motion = require("budouxify.motion")
local words = require("budouxify.words")

--- Range of the blanks between two WORDs, where either may be nil
--- to mean the start or the end of the line.
---@param line string
---@param before { head: number, tail: number } | nil
---@param after { head: number, tail: number } | nil
---@return number, number # start and finish (start of last char); start > finish if none
function M._blanks_between(line, before, after)
	local start = before and words.next_char(line, before.tail) or 0
	local finish = words.prev_char(line, after and after.head or #line)
	return start, finish
end

--- Split a line into alternating WORDs and runs of blanks covering every char.
---@param line string
---@return { start: number, finish: number, word: boolean }[]
function M._objects(line)
	local objects = {}
	local function add_blanks(before, after)
		local start, finish = M._blanks_between(line, before, after)
		if start <= finish then
			table.insert(objects, { start = start, finish = finish, word = false })
		end
	end
	local prev = nil
	for _, word in ipairs(words.parse_words(line)) do
		add_blanks(prev, word)
		table.insert(objects, { start = word.head, finish = word.tail, word = true })
		prev = word
	end
	add_blanks(prev, nil)
	return objects
end

---@param opts { row: number, col: number, curline: string, inner: boolean, count: number? }
---@return { start: { row: number, col: number }, finish: { row: number, col: number } } | nil
function M._find(opts)
	local row, line = opts.row, opts.curline
	if not line or line == "" then
		return nil
	end
	-- 行末より右の仮想カーソル(v$やvirtualedit)は最後の文字として扱う
	local col = math.min(opts.col, words.prev_char(line, #line))
	local count = opts.count or 1

	-- objectsは行を隙間なく敷き詰めるので、colを含むのは次のobjectが始まる前の最後のもの
	-- (finishは最終文字の開始バイトなので、多バイト文字の途中のcolと比較できない)
	local objects = M._objects(line)
	local first = 1
	while objects[first + 1] and objects[first + 1].start <= col do
		first = first + 1
	end

	local start, last = objects[first].start, first
	if opts.inner then
		-- iWはWORDも空白の連続も1つと数える
		last = math.min(first + count - 1, #objects)
	else
		-- aWはWORDをcount個選択する
		local n = 0
		for i = first, #objects do
			last = i
			if objects[i].word then
				n = n + 1
				if n == count then
					break
				end
			end
		end
		-- WORDから始めたときは後続の空白も含め、WORDで終わって後続がなければ
		-- 代わりに先行する空白を含める。ただし行頭のインデントはVimと同様に含めない
		if objects[first].word then
			local after, before = objects[last + 1], objects[first - 1]
			if after and not after.word then
				last = last + 1
			elseif objects[last].word and before and not before.word and objects[first - 2] then
				start = before.start
			end
		end
	end
	return { start = { row = row, col = start }, finish = { row = row, col = objects[last].finish } }
end

---@param opts { inner: boolean, count: number?, row: number?, col: number?, curline: string?, buf: number?, error_handler?: function }
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

	local ok2, range =
		pcall(M._find, { row = row, col = col, curline = curline, inner = opts.inner, count = opts.count })
	if not ok2 then
		handle_error(tostring(range))
		return nil
	end
	return range
end

--- Visually select the range for use in operator-pending and visual mode mappings.
---@param opts { inner: boolean, error_handler?: function }
function M.select(opts)
	local range = M.find({ inner = opts.inner, count = vim.v.count1, error_handler = opts.error_handler })
	if not range then
		return
	end
	-- ビジュアルモードなら一旦抜けてから選択し直す
	if vim.fn.mode():match("^[vV\22]") then
		-- vim.keycodeはNeovim 0.10以降なのでnvim_replace_termcodesを使う
		vim.cmd("normal! " .. vim.api.nvim_replace_termcodes("<Esc>", true, false, true))
	end
	vim.api.nvim_win_set_cursor(0, { range.start.row, range.start.col })
	vim.cmd("normal! v")
	local finish = range.finish.col
	-- 'selection'がexclusiveだとカーソル位置の文字が選択に含まれないので、1文字先に置く
	if vim.o.selection == "exclusive" then
		local line = vim.api.nvim_buf_get_lines(0, range.finish.row - 1, range.finish.row, true)[1]
		finish = words.next_char(line, finish)
	end
	vim.api.nvim_win_set_cursor(0, { range.finish.row, finish })
end

return M
