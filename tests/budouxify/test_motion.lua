local MiniTest = require("mini.test")

local T = MiniTest.new_set()

local M = require("budouxify.motion")

do
	local base_name = "budouxify.motion._find_jump_pos: "
	local charlen = #"あ"
	local segments = {
		"あああ",
		"いいい",
		"ううう",
	}
	local heads = { 0 } -- cursor位置なので0始まり
	for i, segment in ipairs(segments) do
		table.insert(heads, heads[i] + #segment)
	end

	T[base_name .. "Wは現在のセグメントの次のセグメントの先頭に移動する"] = function()
		for idx = 1, #segments - 1 do
			for col = heads[idx], heads[idx + 1] - 1 do
				MiniTest.expect.equality(M._find_jump_pos_from_segments(segments, col, true), heads[idx + 1])
			end
		end
	end

	T[base_name .. "カーソル位置がセグメントの末尾より手前の時、Eは現在のセグメントの末尾に移動する"] = function()
		for idx = 1, #segments - 1 do
			for col = heads[idx], heads[idx + 1] - charlen - 1 do
				MiniTest.expect.equality(M._find_jump_pos_from_segments(segments, col, false), heads[idx + 1] - charlen)
			end
		end
	end

	T[base_name .. "カーソル位置がセグメントの末尾の時、Eは次のセグメントの末尾に移動する"] = function()
		for idx = 1, #segments - 1 do
			for col = heads[idx + 1] - charlen, heads[idx + 1] - 1 do
				MiniTest.expect.equality(M._find_jump_pos_from_segments(segments, col, false), heads[idx + 2] - charlen)
			end
		end
	end
end

return T
