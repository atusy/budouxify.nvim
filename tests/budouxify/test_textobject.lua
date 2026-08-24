local MiniTest = require("mini.test")

local T = MiniTest.new_set()

local M = require("budouxify.textobject")

--- Register parametrized test cases written in the visual DSL.
---
--- Each parameter is a marker line, a buffer line, and an optional count.
--- The marker line annotates the buffer line with `^` (cursor), `[` (start
--- of the expected range) and `]` (start of the last char of the expected
--- range). Markers are matched by byte offset, so a marker over a full-width
--- char must be its 3-byte variant (＾［］). A marker line without `[` and
--- `]` expects nil.
---@param T table MiniTest set to register the cases to
---@param parameters_list table<string, table> case name -> parameters
---@param inner boolean
local function register_cases(T, parameters_list, inner)
	for name, parameters in pairs(parameters_list) do
		T[name] = MiniTest.new_set({ parametrize = parameters })
		T[name][inner and "iW" or "aW"] = function(marker, line, count)
			local col_cursor = vim.regex("[\\^＾]"):match_str(marker)
			local col_start = vim.regex("[\\[［]"):match_str(marker)
			local col_finish = vim.regex("[\\]］]"):match_str(marker)
			if (col_start == nil) ~= (col_finish == nil) then
				error("marker line must have both or neither of [ and ]: " .. marker)
			end
			local expect = col_start and { start = { row = 1, col = col_start }, finish = { row = 1, col = col_finish } }
				or nil
			local found = M.find({
				inner = inner,
				count = count,
				row = 1,
				col = col_cursor,
				curline = line,
				error_handler = error,
			})
			MiniTest.expect.equality(found, expect)
		end
	end
end

register_cases(T, {
	["iW: Cursor on ASCII WORD"] = {
		{ "[^]", "abc" },
		{ "[^]", "abc  def" },
		{ "     [^]", "abc  def" },
		{ "    [^]", "abc a1%" },
		-- cursor on the last char
		{ "[ ^]", "abcd" },
		-- cursor virtually past the end of the line (visual mode with `$`, virtualedit)
		{ "[ ]^", "abc" },
		{ "    [ ]^", "abc def" },
	},
	["iW: Cursor on empty line"] = {
		{ "^", "" },
	},
	["iW: With count"] = {
		-- WORDs and blank runs both count as objects
		{ "[^ ]", "abc def ghi", 2 },
		{ "[^    ]", "abc def ghi", 3 },
		{ "   [^  ]", "abc  def", 2 },
		{ "［＾　　　　　］", "今日は天気です。 GOOD", 2 },
		-- stops at the end of the line
		{ "[^        ]", "abc def ghi", 99 },
	},
	["iW: Cursor on non-ASCII WORD"] = {
		{ "［＾］", "今日は" },
		{ "［＾］", "今日は天気です。" },
		{ "　　　［＾　　］", "今日は天気です。" },
		{ "         ［＾］", "Neovimの設定はinit.lua" },
	},
	["iW: Cursor on [%s　]"] = {
		{ "   [^]", "abc   def" },
		{ "   [ ^]", "abc    def" },
		{ "   [＾]", "abc 　	def" },
		-- leading and trailing blanks
		{ "[^]", "   abc" },
		{ "   [ ^ ]", "abc     " },
		{ "[^]", "   " },
	},
}, true)

register_cases(T, {
	["aW: Cursor on WORD followed by blanks"] = {
		{ "[^   ]", "abc   def" },
		{ "[^ ]", "abc	def" },
		{ "［＾　 ］", "今日は 　天気です。" },
		{ "         ［＾　］", "Neovimの設定は init.lua" },
		-- trailing blanks of the last WORD
		{ "[^   ]", "abc   " },
	},
	["aW: Cursor on WORD without trailing blanks"] = {
		-- leading blanks are included instead
		{ "   [  ^ ]", "abc   def" },
		{ "         [   ＾　　　］", "今日は 　天気です。" },
		-- line-leading indentation is not absorbed (matches Vim)
		{ "   [^]", "   abc" },
		-- no blanks around: only the WORD
		{ "[^]", "abc" },
		{ "　　　［＾　　］", "今日は天気です。" },
		{ "[^]", "abc今日は" },
		-- cursor virtually past the end of the line
		{ "   [  ]^", "abc def" },
	},
	["aW: Cursor on [%s　]"] = {
		{ "   [^   ]", "abc   def" },
		{ "   [＾   ]", "abc 　 def" },
		{ "[^   ]", "   abc" },
		-- trailing blanks: nothing follows
		{ "   [^]", "abc   " },
	},
	["aW: With count"] = {
		-- each WORD comes with its trailing blanks
		{ "[^     ]", "abc def ghi", 2 },
		-- the last WORD has no trailing blanks: fall back to leading blanks
		{ "[^    ]", "abc def", 2 },
		{ " [^    ]", " abc def", 2 },
		-- from blanks: blanks then WORDs, without trailing blanks
		{ "   [^      ]", "abc  def ghi", 2 },
		-- stops at the end of the line
		{ "[^        ]", "abc def ghi", 99 },
		-- an oversized count already consumed the trailing blanks:
		-- no leading-blank fallback
		{ "     [^   ]", "one  two   ", 2 },
	},
}, false)

-- A single-char WORD cannot be written in the DSL: its cursor, start, and
-- finish markers would all share one byte.
T["single-char WORD"] = MiniTest.new_set()

T["single-char WORD"]["iW selects just the char"] = function()
	local found = M.find({ inner = true, row = 1, col = 0, curline = "a b", error_handler = error })
	MiniTest.expect.equality(found, { start = { row = 1, col = 0 }, finish = { row = 1, col = 0 } })
end

-- NUL bytes are WORD chars like in Vim, and are reachable from real
-- buffers: nvim_buf_get_lines returns them as-is.
T["single-char WORD"]["iW treats a NUL byte as part of the WORD"] = function()
	local found = M.find({ inner = true, row = 1, col = 1, curline = "a\0b", error_handler = error })
	MiniTest.expect.equality(found, { start = { row = 1, col = 0 }, finish = { row = 1, col = 2 } })

	-- through an actual buffer, without supplying curline
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "a\0b" })
	local found2 = M.find({ buf = buf, row = 1, col = 1, inner = true, error_handler = error })
	vim.api.nvim_buf_delete(buf, { force = true })
	MiniTest.expect.equality(found2, found)
end

T["single-char WORD"]["iW contains a cursor on an overlong-encoding byte"] = function()
	-- C0 80 steps as one structural 2-byte char, like Neovim's cursor
	local found = M.find({ inner = true, row = 1, col = 3, curline = "x \192\128 y", error_handler = error })
	MiniTest.expect.equality(found, { start = { row = 1, col = 2 }, finish = { row = 1, col = 2 } })
end

T["single-char WORD"]["iW contains a cursor inside the last char of a WORD"] = function()
	-- col 7 is a continuation byte of は
	local found = M.find({ inner = true, row = 1, col = 7, curline = "今日は abc", error_handler = error })
	MiniTest.expect.equality(found, { start = { row = 1, col = 0 }, finish = { row = 1, col = 6 } })
end

T["single-char WORD"]["iW stops at U+3000 without adjacent ASCII"] = function()
	local found = M.find({ inner = true, row = 1, col = 0, curline = "あ　い", error_handler = error })
	MiniTest.expect.equality(found, { start = { row = 1, col = 0 }, finish = { row = 1, col = 0 } })
end

T["single-char WORD"]["iW selects a single-char budoux segment"] = function()
	-- "Neovimの設定はinit.lua" segments as Neovim / の / 設定は / init.lua
	local found = M.find({ inner = true, row = 1, col = 6, curline = "Neovimの設定はinit.lua", error_handler = error })
	MiniTest.expect.equality(found, { start = { row = 1, col = 6 }, finish = { row = 1, col = 6 } })
end

T["error handling"] = MiniTest.new_set()

T["error handling"]["errors when only row is given"] = function()
	MiniTest.expect.error(function()
		M.find({ row = 1, inner = true, curline = "abc", error_handler = error })
	end)
end

T["error handling"]["normalizes an invalid count to 1"] = function()
	local expect = M.find({ inner = true, row = 1, col = 0, curline = "abc def", error_handler = error })
	for _, count in ipairs({ 0, -1, 0.5, 2.5, 0 / 0, math.huge, "2" }) do
		local found = M.find({
			inner = true,
			count = count,
			row = 1,
			col = 0,
			curline = "abc def",
			error_handler = error,
		})
		MiniTest.expect.equality(found, expect)
	end
end

T["error handling"]["returns nil when row is outside the buffer"] = function()
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "abc" })
	local found = M.find({ buf = buf, row = 5, col = 0, inner = true, error_handler = error })
	vim.api.nvim_buf_delete(buf, { force = true })
	MiniTest.expect.equality(found, nil)
end

T["error handling"]["errors when only col is given"] = function()
	MiniTest.expect.error(function()
		M.find({ col = 0, inner = true, curline = "abc", error_handler = error })
	end)
end

--- Apply `keys` (with mappings) on a buffer and return the resulting lines.
---@param lines string[]
---@param cursor { [1]: number, [2]: number }
---@param keys string
---@return string[]
local function apply(lines, cursor, keys)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_win_set_buf(0, buf)
	vim.api.nvim_win_set_cursor(0, cursor)
	vim.keymap.set({ "x", "o" }, "iW", function()
		M.select({ inner = true })
	end, { buffer = buf })
	vim.keymap.set({ "x", "o" }, "aW", function()
		M.select({ inner = false })
	end, { buffer = buf })
	vim.cmd("normal " .. keys)
	local result = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	vim.api.nvim_buf_delete(buf, { force = true })
	return result
end

T["select"] = MiniTest.new_set()

T["select"]["diW deletes the budoux segment under the cursor"] = function()
	MiniTest.expect.equality(apply({ "今日は天気です。" }, { 1, 12 }, "diW"), { "今日は" })
end

T["select"]["daW deletes the WORD and the trailing blanks"] = function()
	MiniTest.expect.equality(apply({ "abc   def" }, { 1, 1 }, "daW"), { "def" })
end

T["select"]["daW keeps line-leading indentation"] = function()
	MiniTest.expect.equality(apply({ "   abc" }, { 1, 3 }, "daW"), { "   " })
end

T["select"]["viW in visual mode reselects the WORD"] = function()
	MiniTest.expect.equality(apply({ "abc def ghi" }, { 1, 5 }, "vhiWd"), { "abc  ghi" })
end

T["select"]["V and CTRL-V collapse to a charwise selection"] = function()
	MiniTest.expect.equality(apply({ "abc def ghi" }, { 1, 5 }, "ViWd"), { "abc  ghi" })
	MiniTest.expect.equality(apply({ "abc def ghi" }, { 1, 5 }, "\22iWd"), { "abc  ghi" })
end

T["select"]["honors a count"] = function()
	MiniTest.expect.equality(apply({ "abc def ghi" }, { 1, 0 }, "d2aW"), { "ghi" })
	MiniTest.expect.equality(apply({ "abc def ghi" }, { 1, 0 }, "v2iWd"), { "def ghi" })
end

T["select"]["honors selection=exclusive"] = function()
	vim.o.selection = "exclusive"
	local ok, err = pcall(function()
		MiniTest.expect.equality(apply({ "abc def ghi" }, { 1, 5 }, "diW"), { "abc  ghi" })
		MiniTest.expect.equality(apply({ "今日は天気です。" }, { 1, 12 }, "daW"), { "今日は" })
	end)
	vim.o.selection = "inclusive"
	if not ok then
		error(err)
	end
end

T["select"]["diW respects a U+3000 boundary inside Japanese text"] = function()
	MiniTest.expect.equality(apply({ "あ　い" }, { 1, 0 }, "diW"), { "　い" })
end

T["select"]["daW treats NBSP as the trailing blank"] = function()
	MiniTest.expect.equality(apply({ "a\u{00a0}b" }, { 1, 0 }, "daW"), { "b" })
	MiniTest.expect.equality(apply({ "a\u{1680}b" }, { 1, 0 }, "daW"), { "b" })
end

T["select"]["diW deletes the whole WORD around a NUL byte"] = function()
	MiniTest.expect.equality(apply({ "x a\0b y" }, { 1, 3 }, "diW"), { "x  y" })
end

T["select"]["diW deletes an invalid UTF-8 WORD entirely"] = function()
	MiniTest.expect.equality(apply({ "x \128\129 y" }, { 1, 2 }, "diW"), { "x  y" })
	-- overlong encoding: one structural 2-byte char, cursor inside it
	MiniTest.expect.equality(apply({ "x \192\128 y" }, { 1, 3 }, "diW"), { "x  y" })
	-- structurally complete but illegal sequence: one char, like Neovim's
	-- own cursor stepping treats it
	MiniTest.expect.equality(apply({ "x \224\128\128 y" }, { 1, 3 }, "diW"), { "x  y" })
end

T["select"]["operator on an empty line is a no-op"] = function()
	MiniTest.expect.equality(apply({ "", "abc" }, { 1, 0 }, "diW"), { "", "abc" })
end

return T
