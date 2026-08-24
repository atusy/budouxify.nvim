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

--- Byte offset of the char following the one at `col`.
--- Byte-based so that NUL and invalid UTF-8 are stepped over safely.
---@param line string
---@param col number
---@return number
function M.next_char(line, col)
	local i = col + 1
	while i < #line and is_utf8_continuation(string.byte(line, i + 1)) do
		i = i + 1
	end
	return i
end

--- Byte offset of the last char of `string.sub(line, 1, col)`,
--- i.e. of the char preceding the one at `col`. -1 if there is none.
--- Byte-based so that NUL and invalid UTF-8 are stepped over safely.
---@param line string
---@param col number
---@return number
function M.prev_char(line, col)
	local i = col - 1
	while i > 0 and is_utf8_continuation(string.byte(line, i + 1)) do
		i = i - 1
	end
	return i
end

--- Parse a line into WORDs and return their boundaries as byte offsets.
--- A WORD is a run of ASCII chars other than space and tab (as in Vim,
--- control chars and NUL count as WORD chars) or a budoux segment of a
--- run of non-ASCII chars. Blanks are space, tab, and U+3000.
---@param line string
---@return { head: number, tail: number }[] # head: first char, tail: start of last char
function M.parse_words(line)
	local regex_blanks = vim.regex("^[ \t　]\\+")

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
			-- UTF-8の非ASCII文字は全バイトが0x80以上なので、バイト検索で連続の終わりを探せる
			local run_end = string.find(rest, "[%z\1-\127]")
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
