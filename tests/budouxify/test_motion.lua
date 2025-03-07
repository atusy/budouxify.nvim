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
				"  ^ ", -- cursor
				"abc ",
				"   |", -- jump
			},
		},
		-- at the end of last line
		{
			{
				"  ^", -- cursor
				"abc",
			},
		},
	},
}

for name, parameters in pairs(parameters_list) do
	T[name] = MiniTest.new_set({
		parametrize = parameters,
	})

	for motion, cond in pairs({
		W = { head = true, regex = "[WＷ|｜]" },
		E = { head = false, regex = "[EＥ|｜]" },
	}) do
		T[name][motion] = function(parameter)
			-- setup variables
			local lines = {}
			local pos_cursor = { 1, 0 }
			local pos_expect = nil ---@type nil | { [1]: number, [2]: number }
			for _, p in ipairs(parameter) do
				if not vim.regex("[WＷEＥ|｜^＾]"):match_str(p) then
					table.insert(lines, p)
				else
					local col_cursor = vim.regex("[\\^＾]"):match_str(p)
					if col_cursor then
						pos_cursor = { #lines + 1, col_cursor }
					end
					local col_jump = vim.regex(cond.regex):match_str(p)
					if col_jump then
						if col_cursor then
							pos_expect = { #lines + 1, col_jump }
						else
							pos_expect = { #lines, col_jump }
						end
					end
				end
			end

			-- setup buffer
			local buf = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
			vim.api.nvim_win_set_buf(0, buf)
			vim.api.nvim_win_set_cursor(0, pos_cursor)

			-- test
			local ok, pos_found = pcall(M.find_forward, {
				buf = buf,
				row = pos_cursor[1],
				col = pos_cursor[2],
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
				MiniTest.expect.equality(pos_found, { row = pos_expect[1], col = pos_expect[2] })
			end
		end
	end
end

T["Cursor on [%s　]"] = MiniTest.new_set({
	parametrize = {
		-- single WORD
		{ {
			curline = "   aaa",
			cursors = "^  W E",
		} },
		{ {
			curline = "   aaa",
			cursors = " ^ W E",
		} },
		{ {
			curline = "   aaa",
			cursors = "  ^W E",
		} },
		{
			{
				curline = "		aaa", -- tab
				cursors = "^ W E",
			},
		},
		{ {
			curline = "　　123",
			cursors = "＾　W E",
		} },
		{ {
			curline = "  　%%%",
			cursors = "^ 　W E",
		} },
		{ {
			curline = "  　%%%",
			cursors = "  ＾W E",
		} },
		{ {
			curline = "　  あいう",
			cursors = "＾  Ｗ　Ｅ",
		} },
		-- more WORDs
		{ {
			curline = "   a2% aaa",
			cursors = "^  W E",
		} },
		{ {
			curline = "　　1b% aaa",
			cursors = "＾　W E",
		} },
		{ {
			curline = "  　%2c aaa",
			cursors = "^ 　W E",
		} },
		{ {
			curline = "　  あいう aaa",
			cursors = "＾  Ｗ　Ｅ",
		} },
		-- single ASCII WORD followed by Japanese character
		{ {
			curline = "   a2%あ",
			cursors = "^  W E",
		} },
		{ {
			curline = "　　1b%あ",
			cursors = "＾　W E",
		} },
		{ {
			curline = "  　%2cあ",
			cursors = "^ 　W E",
		} },
		-- A Japanese WORD followed by something
		{ {
			curline = "　  今日はGOOD",
			cursors = "＾  Ｗ　Ｅ",
		} },
		{ {
			curline = "  　今日は天気です。",
			cursors = "  ＾Ｗ　Ｅ",
		} },
	},
})

T["Cursor on [%w%p]"] = MiniTest.new_set({
	parametrize = {
		{ {
			curline = "abc def",
			cursors = "^ E W",
		} },
		{ {
			curline = "abc def",
			cursors = "  ^ W E",
		} },
		{ {
			curline = "abc   123",
			cursors = "^ E   W",
		} },
		{ {
			curline = "abc   123",
			cursors = "  ^   W E",
		} },
		{ {
			curline = "abc　　%%%",
			cursors = "  ^　　W E",
		} },
		{ {
			curline = "abc　  あいう",
			cursors = "^ E　  Ｗ",
		} },
		{ {
			curline = "abc　  あいう",
			cursors = "  ^　  Ｗ　Ｅ",
		} },
		{ {
			curline = "abcあいう",
			cursors = "^ EＷ",
		} },
		{ {
			curline = "abcあいう",
			cursors = "  ^Ｗ　Ｅ",
		} },
	},
})

T["Cursor on non-ASCII WORD"] = MiniTest.new_set({
	parametrize = {
		{ {
			curline = "今日はGOOD",
			cursors = "＾　ＥW",
		} },
		{ {
			curline = "今日は GOOD",
			cursors = "＾　Ｅ W",
		} },
		{ {
			curline = "今日は天気です。GOOD",
			cursors = "＾　ＥＷ",
		} },
		{ {
			curline = "今日は天気です。GOOD",
			cursors = "　　　＾　　　ＥW",
		} },
		{ {
			curline = "abc今日は天気です。GOOD",
			cursors = "   　　　＾　　　ＥW",
		} },
		{ {
			curline = "今日はGOOD",
			cursors = "　　＾W  E",
		} },
	},
})

for _, case in pairs({ "Cursor on [%s　]", "Cursor on [%w%p]", "Cursor on non-ASCII WORD" }) do
	for motion, cond in pairs({
		W = { head = true, regex = "[WＷ]" },
		E = { head = false, regex = "[EＥ]" },
	}) do
		T[case][motion] = function(params)
			local from = vim.regex("[\\^＾]"):match_str(params.cursors)
			local to = vim.regex(cond.regex):match_str(params.cursors)
			local given = M.find_forward({
				row = 1,
				col = from,
				curline = params.curline,
				head = cond.head,
			})
			MiniTest.expect.equality(given, { row = 1, col = to })
		end
	end
end

return T
