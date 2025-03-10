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
			local cursor = { 1, 0 }
			local pos_expect = nil ---@type nil | { row: number, col: number }
			for _, p in ipairs(parameter) do
				if not vim.regex("[WＷEＥ|｜^＾]"):match_str(p) then
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
				local pos_found = M.find_forward({
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
			local ok, pos_found = pcall(M.find_forward, {
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

for _, case in pairs({}) do
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
