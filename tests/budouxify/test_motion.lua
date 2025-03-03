local MiniTest = require("mini.test")

local T = MiniTest.new_set()

local M = require("budouxify.motion")

T["Cursor virtually on the end of the line"] = function()
	MiniTest.skip("TODO: This test requires real buffer")
end

T["Cursor on the space"] =
	MiniTest.new_set({ parametrize = {
		{ "    " },
		{ "　　" },
		{ "  　" },
		{ "　  " },
	} })

T["Cursor on the space"]["W motion"] = MiniTest.new_set({
	parametrize = {
		{ "aaa" },
		{ "123" },
		{ "%%%" },
		{ "あいう" },
	},
})
T["Cursor on the space"]["W motion"]["_"] = function(spaces, WORD)
	local pos = M.find_forward({
		row = 1,
		col = 0,
		curline = spaces .. WORD,
		head = true,
	})
	MiniTest.expect.equality(pos, { row = 1, col = spaces:len() })
end

T["Cursor on the space"]["E motion when next WORD starts with %p or %w"] = MiniTest.new_set({
	parametrize = {
		{ "abc", " def" },
		{ "!@$", " def" },
		{ "123", " def" },
		{ "a@3", " def" },
		{ "abc", "あいう" },
		{ "!@$", "あいう" },
		{ "123", "あいう" },
		{ "a@3", "あいう" },
		--   ^cursor
	},
})

T["Cursor on the space"]["E motion when next WORD starts with %p or %w"]["_"] = function(prefix, WORD, suffix)
	local pos = M.find_forward({
		row = 1,
		col = 0,
		curline = prefix .. WORD .. suffix,
		head = false,
	})
	MiniTest.expect.equality(pos, { row = 1, col = prefix:len() + WORD:len() - 1 })
end

T["Cursor on the space"]["E motion when next WORD starts with Japanese"] = MiniTest.new_set({
	parametrize = {
		{ "今日は", "" },
		{ "今日は", "GOOD" },
		{ "今日は", "天気です。" },
		--     E
	},
})

T["Cursor on the space"]["E motion when next WORD starts with Japanese"]["_"] = function(prefix, WORD, suffix)
	local pos = M.find_forward({
		row = 1,
		col = 0,
		curline = prefix .. WORD .. suffix,
		head = false,
	})
	MiniTest.expect.equality(pos, { row = 1, col = prefix:len() + #"今日" - 1 })
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
