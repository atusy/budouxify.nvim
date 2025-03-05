local MiniTest = require("mini.test")

local T = MiniTest.new_set()

local M = require("budouxify.motion")

T["Cursor virtually on the end of the line"] = function()
	MiniTest.skip("TODO: This test requires real buffer")
end

T["Cursor on the space"] = MiniTest.new_set({
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

for motion, cond in pairs({
	W = { head = true, regex = "[WＷ]" },
	E = { head = false, regex = "[EＥ]" },
}) do
	T["Cursor on the space"][motion] = function(params)
		local from = vim.regex("[^＾]"):match_str(params.cursors)
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

T["Cursor on the %w or %p"] = MiniTest.new_set({
	parametrize = {
		{ "abc ", "xxx" },
		{ "abc   ", "123" },
		{ "abc　　", "%%%" },
		{ "abc　  ", "あいう" },
		{ "abc", "あいう" },
		{ "%%%", "あいう" },
		{ "123", "あいう" },
		{ "a%3", "あいう" },
	},
})

T["Cursor on the %w or %p"]["W motion"] = function(prefix, suffix)
	local pos = M.find_forward({
		row = 1,
		col = 0,
		curline = prefix .. suffix,
		head = true,
	})
	MiniTest.expect.equality(pos, { row = 1, col = #prefix })
end

T["Cursor on the %w or %p"]["E motion at the end of [%w%p]+"] = function(prefix, suffix)
	-- abc xxx
	--   ^   E
	-- abcあいう
	--   ^    E
	local pos = M.find_forward({
		row = 1,
		col = 2,
		curline = prefix .. suffix,
		head = false,
	})
	local d1, d2 = vim.regex(".$"):match_str(suffix)
	MiniTest.expect.equality(pos, { row = 1, col = #(prefix .. suffix) - d2 + d1 })
end

T["Cursor on the %w or %p"]["E motion not at the end of [%w%p]+"] = function(prefix, suffix)
	-- abc xxx
	-- abcあいう
	-- ^ E
	local pos = M.find_forward({
		row = 1,
		col = 0,
		curline = prefix .. suffix,
		head = false,
	})
	MiniTest.expect.equality(pos, { row = 1, col = 2 })
end

T["Cursor on Japanese segment"] = MiniTest.new_set({
	-- { { "今日は", "天気です。", "GOOD" }, 2 }
	-- の場合、2番目のセグメントにカーソルを置いたときの挙動をテスト
	-- 「天」、「気」、「で」、「す」、「。」のそれぞれの位置を試す
	parametrize = {
		{ { "今日は", "GOOD" }, 1 },
		{ { "今日は", "天気です。", "GOOD" }, 2 },
		{ { " ", "今日は", "天気です。", "GOOD" }, 3 },
		{ { "abc ", "今日は", "天気です。", "GOOD" }, 3 },
	},
})

T["Cursor on Japanese segment"]["W motion"] = function(segments, nth_segment)
	local line = table.concat(segments)
	local col_base = 0
	if nth_segment > 1 then
		for i = 2, nth_segment do
			col_base = col_base + #segments[i - 1]
		end
	end

	local col = col_base
	local segmentchars = vim.fn.split(segments[nth_segment], "\\zs")
	for i, _ in pairs(segmentchars) do
		if i > 1 then
			col = col + #segmentchars[i - 1]
		end
		local pos = M.find_forward({
			row = 1,
			col = col,
			curline = line,
			head = true,
		})
		MiniTest.expect.equality(pos, { row = 1, col = col_base + #segments[nth_segment] })
	end
end

return T
