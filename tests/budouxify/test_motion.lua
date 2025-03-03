local MiniTest = require("mini.test")

local T = MiniTest.new_set()

local M = require("budouxify.motion")

T["Cursor on the space"] =
	MiniTest.new_set({ parametrize = {
		{ "   " },
		{ "　　" },
		{ "  　" },
		{ "　  " },
	} })

T["Cursor on the space"]["W motion"] = function(spaces)
	local pos = M.find_forward({
		row = 1,
		col = 0,
		curline = spaces .. "abc",
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

return T
