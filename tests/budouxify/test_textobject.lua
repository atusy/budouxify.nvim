local MiniTest = require("mini.test")

local T = MiniTest.new_set()

local M = require("budouxify.textobject")

--- Register parametrized test cases written in the visual DSL.
---
--- Each parameter is a list of two strings: a marker line and a buffer line.
--- The marker line annotates the buffer line with `^` (cursor), `[` (start
--- of the expected range) and `]` (start of the last char of the expected
--- range). Full-width markers annotate full-width chars. A marker line
--- without `[`/`]` expects nil.
---@param T table MiniTest set to register the cases to
---@param parameters_list table<string, table> case name -> parameters
---@param inner boolean
local function register_cases(T, parameters_list, inner)
	for name, parameters in pairs(parameters_list) do
		T[name] = MiniTest.new_set({ parametrize = parameters })
		T[name][inner and "iW" or "aW"] = function(marker, line)
			local col_cursor = vim.regex("[\\^＾]"):match_str(marker)
			local col_start = vim.regex("[\\[［]"):match_str(marker)
			local col_finish = vim.regex("[\\]］]"):match_str(marker)
			local expect = col_start and { start = { row = 1, col = col_start }, finish = { row = 1, col = col_finish } }
				or nil
			local found = M.find({ inner = inner, row = 1, col = col_cursor, curline = line, error_handler = error })
			MiniTest.expect.equality(found, expect)
		end
	end
end

register_cases(T, {
	["iW: Cursor on ASCII WORD"] = {
		{ "[^]", "abc" },
		{ "[^]", "abc  def" },
		{ "     [^]", "abc  def" },
		{ "    [^]", "abc a1%" },
	},
	["iW: Cursor on non-ASCII WORD"] = {
		{ "［＾］", "今日は" },
		{ "［＾］", "今日は天気です。" },
		{ "　　　［＾　　］", "今日は天気です。" },
		{ "         ［＾］", "Neovimの設定はinit.lua" },
	},
	["iW: Cursor on [%s　]"] = {
		{ "   [^]", "abc   def" },
		{ "   [ ^]", "abc    def" },
		{ "   [＾]", "abc 　	def" },
		-- leading and trailing blanks
		{ "[^]", "   abc" },
		{ "   [ ^ ]", "abc     " },
		{ "[^]", "   " },
	},
}, true)

register_cases(T, {
	["aW: Cursor on WORD followed by blanks"] = {
		{ "[^   ]", "abc   def" },
		{ "［＾　 ］", "今日は 　天気です。" },
		{ "         ［＾　］", "Neovimの設定は init.lua" },
	},
	["aW: Cursor on WORD without trailing blanks"] = {
		-- leading blanks are included instead
		{ "   [  ^ ]", "abc   def" },
		{ "         [   ＾　　　］", "今日は 　天気です。" },
		-- no blanks around: only the WORD
		{ "[^]", "abc" },
		{ "　　　［＾　　］", "今日は天気です。" },
		{ "[^]", "abc今日は" },
	},
	["aW: Cursor on [%s　]"] = {
		{ "   [^   ]", "abc   def" },
		{ "   [＾   ]", "abc 　 def" },
		{ "[^   ]", "   abc" },
		-- trailing blanks: nothing follows
		{ "   [^]", "abc   " },
	},
}, false)

return T
