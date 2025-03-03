local MiniTest = require("mini.test")

local T = MiniTest.new_set()

local M = require("budouxify.motion")

T["W: cursor on the space"] = MiniTest.new_set({ parametrize = {
	{ "  　" },
	{ "　  " },
} })
T["W: cursor on the space"]["works"] = function(spaces)
	local pos = M.find_forward({
		row = 1,
		col = 0,
		curline = spaces .. "abc",
		head = true,
	})
	MiniTest.expect.equality(pos, { row = 1, col = spaces:len() })
end

T["E: cursor on the space and next word starts with %w"] = function()
	local pos = M.find_forward({ row = 1, col = 0, curline = "   abc def", head = false })
	MiniTest.expect.equality(pos, { row = 1, col = 5 })
end

T["E: cursor on the space and next word starts with %p"] = function()
	local pos = M.find_forward({ row = 1, col = 0, curline = "   %bc def", head = false })
	MiniTest.expect.equality(pos, { row = 1, col = 5 })
end

return T
