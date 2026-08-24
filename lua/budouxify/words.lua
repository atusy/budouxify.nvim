--- The WORD tokenizer shared by motions and text objects.
local M = {}

--- budoux.luaはモデルの読み込みを毎回やり直すので、パーサを1度だけ作って使い回す
---@type fun(sentence: string): string[]
local parse_japanese = nil
local function get_parser()
	if not parse_japanese then
		parse_japanese = require("budoux").load_japanese_model().parse
	end
	return parse_japanese
end

--- Segment Japanese text with budoux.
---@param text string
---@return string[]
function M.parse_japanese(text)
	return get_parser()(text)
end

---@param byte number
---@return boolean
local function is_utf8_continuation(byte)
	return byte >= 0x80 and byte < 0xC0
end

--- Length in bytes of the UTF-8 char led by `byte`, or nil for a
--- continuation byte or FE/FF. Mirrors Neovim's structural utf8len_tab
--- (including the legacy 5- and 6-byte forms), so boundaries land where
--- the editor's own cursor stepping does.
---@param byte number
---@return number | nil
local function utf8_length(byte)
	if byte < 0x80 then
		return 1
	elseif byte < 0xC0 then
		return nil
	elseif byte < 0xE0 then
		return 2
	elseif byte < 0xF0 then
		return 3
	elseif byte < 0xF8 then
		return 4
	elseif byte < 0xFC then
		return 5
	elseif byte < 0xFE then
		return 6
	end
	return nil
end

--- Byte offset of the char following the one at `col`.
--- Byte-based so that NUL is stepped over safely. Like Neovim's own char
--- stepping (utf_ptr2len), validation is structural: a lead byte with its
--- continuation bytes counts as one char even if the codepoint is illegal
--- (overlong, surrogate); structurally broken bytes count one byte each.
---@param line string
---@param col number
---@return number
function M.next_char(line, col)
	local len = utf8_length(string.byte(line, col + 1) or 0) or 1
	for i = col + 2, col + len do
		if i > #line or not is_utf8_continuation(string.byte(line, i)) then
			len = 1
			break
		end
	end
	return col + len
end

--- Byte offset of the last char of `string.sub(line, 1, col)`,
--- i.e. of the char preceding the one at `col`. -1 if there is none.
--- Byte-based so that NUL is stepped over safely; validation is
--- structural, like next_char.
---@param line string
---@param col number
---@return number
function M.prev_char(line, col)
	local i = col - 1
	while i > 0 and col - i < 6 and is_utf8_continuation(string.byte(line, i + 1)) do
		i = i - 1
	end
	if utf8_length(string.byte(line, i + 1) or 0) == col - i then
		return i
	end
	return col - 1
end

-- Vimがword/WORDモーションで空白(class 0)とみなす非ASCII文字
-- (VimソースのutfClassTableより: NBSP、オガム空白、U+2000-200B、LS/PS、NNBSP、MMSP、全角空白)
local mb_blank_chars = (function()
	local codepoints = { 0x00a0, 0x1680, 0x2028, 0x2029, 0x202f, 0x205f, 0x3000 }
	for cp = 0x2000, 0x200b do
		table.insert(codepoints, cp)
	end
	local chars = ""
	for _, cp in ipairs(codepoints) do
		chars = chars .. vim.fn.nr2char(cp, 1)
	end
	return chars
end)()
local regex_blanks = vim.regex("^[ \t" .. mb_blank_chars .. "]\\+")
local regex_mb_blank = vim.regex("[" .. mb_blank_chars .. "]")

--- Parse a line into WORDs and return their boundaries as byte offsets.
--- A WORD is a run of ASCII chars other than space and tab (as in Vim,
--- control chars and NUL count as WORD chars) or a budoux segment of a
--- run of non-ASCII chars. Blanks are space, tab, and the non-ASCII
--- chars Vim classifies as white (NBSP, U+2000-200B, U+3000, ...).
---@param line string
---@return { head: number, tail: number }[] # head: first char, tail: start of last char
function M.parse_words(line)
	local words = {}
	local i = 0
	while i < #line do
		local rest = string.sub(line, i + 1)
		local _, blanks = regex_blanks:match_str(rest)
		-- Luaパターンはバイト単位なのでNULや制御文字も安全に扱える
		local ascii_word = string.match(rest, "^[%z\1-\8\11-\31\33-\127]+")
		if blanks then
			i = i + blanks
		elseif ascii_word then
			table.insert(words, { head = i, tail = i + #ascii_word - 1 })
			i = i + #ascii_word
		else
			-- 非ASCII文字の連続をbudouxのセグメントに分割する
			-- ASCIIバイト(NUL含む)はバイト検索で、非ASCIIの空白はvim.regexで連続の終わりを探す
			-- (vim.regexはNULから先が見えないが、バイト検索が先にNULで止まるので安全)
			local run_end = string.find(rest, "[%z\1-\127]")
			local mb_blank = regex_mb_blank:match_str(rest)
			if mb_blank and (not run_end or mb_blank + 1 < run_end) then
				run_end = mb_blank + 1
			end
			local run = run_end and string.sub(rest, 1, run_end - 1) or rest
			-- budouxは不正なUTF-8に対して空を返すので、runごと1つのWORDとして扱い無限ループを防ぐ
			local segments = M.parse_japanese(run)
			if #segments == 0 then
				segments = { run }
			end
			for _, segment in ipairs(segments) do
				table.insert(words, { head = i, tail = i + M.prev_char(segment, #segment) })
				i = i + #segment
			end
		end
	end
	return words
end

return M
