local MiniTest = require("mini.test")

local T = MiniTest.new_set()

local M = require("budouxify.motion")

T["budouxify.motion._find_jump_pos"] = function()
	local delta = #"あ"
	local segments = {
		"あああ",
		"いいい",
		"ううう",
	}
	local heads = { 0 } -- cursor位置なので0始まり
	for i, segment in ipairs(segments) do
		table.insert(heads, heads[i] + #segment)
	end

	-- Wは現在のセグメントの次のセグメントの先頭に移動する
	for idx = 1, #segments - 1 do
		for col = heads[idx], heads[idx + 1] - 1 do
			MiniTest.expect.equality(M._find_jump_pos(segments, col, true), heads[idx + 1])
		end
	end

	-- カーソル位置がセグメントの末尾より手前の時、Eは現在のセグメントの末尾に移動する
	for idx = 1, #segments - 1 do
		for col = heads[idx], heads[idx + 1] - delta - 1 do
			MiniTest.expect.equality(M._find_jump_pos(segments, col, false), heads[idx + 1] - delta)
		end
	end

	-- カーソル位置がセグメントの末尾の時、Eは次のセグメントの末尾に移動する
	for idx = 1, #segments - 1 do
		for col = heads[idx + 1] - delta, heads[idx + 1] - 1 do
			MiniTest.expect.equality(M._find_jump_pos(segments, col, false), heads[idx + 2] - delta)
		end
	end
end

return T
