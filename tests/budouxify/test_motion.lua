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
	parametrize = {
		{ { "今日は", "GOOD" } },
	},
})

T["Cursor on Japanese segment"]["W motion"] = function(segments)
	local line = table.concat(segments)
	local pos = M.find_forward({
		row = 1,
		col = 0,
		curline = line,
		head = true,
	})
	MiniTest.expect.equality(pos, { row = 1, col = #segments[1] })
end

return T
