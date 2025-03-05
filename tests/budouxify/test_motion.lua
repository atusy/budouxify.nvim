local MiniTest = require("mini.test")

local T = MiniTest.new_set()

local M = require("budouxify.motion")

T["Cursor virtually on the end of the line"] = function()
	MiniTest.skip("TODO: This test requires real buffer")
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
