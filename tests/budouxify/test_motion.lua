local MiniTest = require("mini.test")

local T = MiniTest.new_set()

local M = require("budouxify.motion")

T["W: cursor on the space"] = function()
	local pos = M.find_forward({ row = 1, col = 0, curline = "  　345", head = true })
	if pos then
		MiniTest.expect.equality(pos, { row = 1, col = 5 })
	else
		MiniTest.expect.equality(pos, nil)
	end
end

T["W: cursor on the zenkaku-space"] = function()
	local spaces = "　 "
	local pos = M.find_forward({ row = 1, col = 0, curline = spaces .. "abc", head = true })
	if pos then
		MiniTest.expect.equality(pos, { row = 1, col = spaces:len() })
	else
		MiniTest.expect.equality(pos, nil)
	end
end

T["E: cursor on the space and next word starts with %w"] = function()
	local pos = M.find_forward({ row = 1, col = 0, curline = "   abc def", head = false })
	if not pos then
		error("pos is nil")
	end
	MiniTest.expect.equality(pos, { row = 1, col = 5 })
end

T["E: cursor on the space and next word starts with %p"] = function()
	local pos = M.find_forward({ row = 1, col = 0, curline = "   %bc def", head = false })
	if not pos then
		error("pos is nil")
	end
	MiniTest.expect.equality(pos, { row = 1, col = 5 })
end

return T
