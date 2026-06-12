local MiniTest = require("mini.test")

local T = MiniTest.new_set()

local M = require("budouxify.motion")

local parameters_list = {
	["Cursor virtually on the end of the line"] = {
		{
			{
				"  ^", -- cursor
				"abc",
				"a c",
				"|  ", -- jump
			},
		},
		{
			{
				"  ^", -- curosor
				"abc",
				"  c",
				"  |", -- jump
			},
		},
		{
			{
				"  ^", -- cursor
				"abc",
				"",
				"  ",
				"　　 	",
				"  c",
				"  |", -- jump
			},
		},
		{
			{
				"  ^", -- cursor
				"abc",
				"  abc",
				"  W E", -- jump
			},
		},
		{
			{
				"  ^", -- cursor
				"abc",
				"あ c",
				"｜  ", -- jump
			},
		},
		{
			{
				"",
				"  ^ ", -- cursor
				"abc ",
				"   |", -- jump
			},
		},
		-- at the end of last line
		{
			{
				"",
				"  ^", -- cursor
				"abc",
			},
		},
	},
	["Cursor on [%s　]"] = {
		-- single WORD
		{ {
			"^  W E",
			"   aaa",
		} },
		{ {
			" ^ W E",
			"   aaa",
		} },
		{ {
			"  ^W E",
			"   aaa",
		} },
		{
			{
				"^ W E",
				"		aaa", -- tab
			},
		},
		{ {
			"＾　W E",
			"　　123",
		} },
		{ {
			"^ 　W E",
			"  　%%%",
		} },
		{ {
			"  ＾W E",
			"  　%%%",
		} },
		{ {
			"＾  Ｗ　Ｅ",
			"　  あいう",
		} },
		-- more WORDs
		{ {
			"^  W E",
			"   a2% aaa",
		} },
		{ {
			"＾　W E",
			"　　1b% aaa",
		} },
		{ {
			"^ 　W E",
			"  　%2c aaa",
		} },
		{ {
			"＾  Ｗ　Ｅ",
			"　  あいう aaa",
		} },
		-- single ASCII WORD followed by Japanese character
		{ {
			"^  W E",
			"   a2%あ",
		} },
		{ {
			"＾　W E",
			"　　1b%あ",
		} },
		{ {
			"^ 　W E",
			"  　%2cあ",
		} },
		-- A Japanese WORD followed by something
		{ {
			"＾  Ｗ　Ｅ",
			"　  今日はGOOD",
		} },
		{ {
			"  ＾Ｗ　Ｅ",
			"  　今日は天気です。",
		} },
	},
	["Cursor on [%w%p]"] = {
		{ {
			"^ E W",
			"abc def",
		} },
		{ {
			"  ^ W E",
			"abc def",
		} },
		{ {
			"^ E   W",
			"abc   123",
		} },
		{ {
			"  ^   W E",
			"abc   123",
		} },
		{ {
			"  ^　　W E",
			"abc　　%%%",
		} },
		{ {
			"^ E　  Ｗ",
			"abc　  あいう",
		} },
		{ {
			"  ^　  Ｗ　Ｅ",
			"abc　  あいう",
		} },
		{ {
			"^ EＷ",
			"abcあいう",
		} },
		{ {
			"  ^Ｗ　Ｅ",
			"abcあいう",
		} },
		{ {
			"^ E",
			"abc",
			"def",
			"W",
		} },
	},
	["Cursor on empty line"] = {
		{
			{
				"^",
				"",
				"abc",
				"W E",
			},
		},
		{
			{
				"^",
				"",
				"",
				"  abc",
				"  W E",
			},
		},
	},
	["Cursor on non-ASCII WORD"] = {
		{ {
			"＾　ＥW",
			"今日はGOOD",
		} },
		{ {
			"＾　Ｅ W",
			"今日は GOOD",
		} },
		{ {
			"＾　ＥＷ",
			"今日は天気です。GOOD",
		} },
		{ {
			"　　　＾　　　ＥW",
			"今日は天気です。GOOD",
		} },
		{ {
			"   　　　＾　　　ＥW",
			"abc今日は天気です。GOOD",
		} },
		{ {
			"　　＾W  E",
			"今日はGOOD",
		} },
		{ {
			"      ＾Ｗ　Ｅ",
			"Neovimの設定はinit.lua",
		} },
		-- A Japanese WORD followed by a space and another Japanese WORD
		{ {
			"＾　Ｅ Ｗ",
			"今日は 明日も",
		} },
		-- Cursor on the last Japanese char before a space
		{ {
			"　　＾ W  E",
			"今日は GOOD",
		} },
		-- Cursor in the middle of a Japanese WORD followed by a space
		{ {
			"　＾Ｅ Ｗ",
			"あいう えお",
		} },
		-- Cursor on the last char of a Japanese WORD followed by a Japanese WORD
		{ {
			"　　＾ ＷＥ",
			"あいう えお",
		} },
		-- Jump from a Japanese WORD to the next line
		{
			{
				"＾　Ｅ",
				"今日は",
				"GOOD",
				"W",
			},
		},
		-- Cursor on the last char of a line
		{
			{
				"　　＾",
				"今日は",
				"GOOD",
				"W  E",
			},
		},
		-- Cursor on the last segment of multiple segments
		{
			{
				"　　　＾　　　Ｅ",
				"今日は天気です。",
				"GOOD",
				"W",
			},
		},
		-- No more WORDs in the buffer
		{
			{
				"",
				"＾　｜",
				"今日は",
			},
		},
	},
	["Jump from ASCII to non-ASCII line"] = {
		{
			{
				"^ E",
				"abc",
				"今日は",
				"Ｗ",
			},
		},
		{
			{
				"  ^",
				"abc",
				"今日は",
				"Ｗ　Ｅ",
			},
		},
	},
}

--- Register parametrized test cases written in the visual DSL.
---
--- Each parameter is a list of strings. A string containing a marker
--- (cursor or jump) annotates the buffer line next to it: a marker line
--- with a cursor marker refers to the FOLLOWING line, and one without
--- refers to the PRECEDING line. Other strings are buffer lines.
---@param T table MiniTest set to register the cases to
---@param parameters_list table<string, table> case name -> parameters
---@param motions table<string, { head: boolean, regex: string }> motion name -> jump marker
---@param marker_regex string regex to detect marker lines
---@param find fun(opts: table): { row: number, col: number } | nil
local function register_cases(T, parameters_list, motions, marker_regex, find)
	for name, parameters in pairs(parameters_list) do
		T[name] = MiniTest.new_set({
			parametrize = parameters,
		})

		for motion, cond in pairs(motions) do
			T[name][motion] = function(parameter)
				-- setup variables
				local lines = {}
				local cursor = { 1, 0 }
				local pos_expect = nil ---@type nil | { row: number, col: number }
				for _, p in ipairs(parameter) do
					if not vim.regex(marker_regex):match_str(p) then
						table.insert(lines, p)
					else
						local col_cursor = vim.regex("[\\^＾]"):match_str(p)
						if col_cursor then
							cursor = { #lines + 1, col_cursor }
						end
						local col_jump = vim.regex(cond.regex):match_str(p)
						if col_jump then
							if col_cursor then
								pos_expect = { row = #lines + 1, col = col_jump }
							else
								pos_expect = { row = #lines, col = col_jump }
							end
						end
					end
				end

				-- early assertions
				if #lines == 0 then
					error("No lines found")
				end

				if #lines == 1 then
					-- efficient tests without buffer
					local pos_found = find({
						row = cursor[1],
						col = cursor[2],
						head = cond.head,
						curline = lines[1],
						error_handler = error,
					})
					MiniTest.expect.equality(pos_found, pos_expect)
					return
				end

				-- setup buffer
				local buf = vim.api.nvim_create_buf(false, true)
				vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
				vim.api.nvim_win_set_buf(0, buf)
				vim.api.nvim_win_set_cursor(0, cursor)

				-- test
				local ok, pos_found = pcall(find, {
					buf = buf,
					row = cursor[1],
					col = cursor[2],
					head = cond.head,
					error_handler = error,
				})

				-- teardown buffer
				vim.api.nvim_buf_delete(buf, { force = true })

				-- assertion
				if not ok then
					error(pos_found)
				end
				if pos_expect == nil then
					MiniTest.expect.equality(pos_found, nil)
				else
					MiniTest.expect.equality(pos_found, pos_expect)
				end
			end
		end
	end
end

register_cases(T, parameters_list, {
	W = { head = true, regex = "[WＷ|｜]" },
	E = { head = false, regex = "[EＥ|｜]" },
}, "[WＷEＥ|｜^＾]", M.find_forward)

local parameters_list_backward = {
	["B/gE: Cursor on ASCII WORD"] = {
		{ {
			"B ^",
			"abc",
		} },
		-- cursor on the head of a WORD
		{ {
			"B G ^",
			"abc def",
		} },
		-- cursor in the middle of the second WORD
		{ {
			"  G B^",
			"abc def",
		} },
		-- punctuation and digits form WORDs
		{ {
			"  G B ^",
			"a1% de2",
		} },
	},
	["B/gE: Cursor on non-ASCII WORD"] = {
		-- cursor in the middle of the second segment
		{ {
			"　　ＧＢ　＾",
			"今日は天気です。",
		} },
	},
	["B/gE: Cursor on [%s　]"] = {
		{ {
			"B G^",
			"abc def",
		} },
		{ {
			"B G ＾",
			"abc 　def",
		} },
	},
}

register_cases(T, parameters_list_backward, {
	B = { head = true, regex = "[BＢ|｜]" },
	gE = { head = false, regex = "[GＧ|｜]" },
}, "[BＢGＧ|｜^＾]", M.find_backward)

T["error handling"] = MiniTest.new_set()

T["error handling"]["errors when only row is given"] = function()
	MiniTest.expect.error(function()
		M.find_forward({ row = 1, head = true, curline = "abc", error_handler = error })
	end)
end

T["error handling"]["errors when only col is given"] = function()
	MiniTest.expect.error(function()
		M.find_forward({ col = 0, head = true, curline = "abc", error_handler = error })
	end)
end

return T
