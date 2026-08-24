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

--- Parse a line into WORDs and return their boundaries as byte offsets.
--- A WORD is a run of ASCII alphanumerics/punctuations or a budoux
--- segment of a run of other non-space characters.
---@param line string
---@return { head: number, tail: number }[] # head: first char, tail: start of last char
function M.parse_words(line)
	local regex_spaces = vim.regex("^[[:space:]　]\\+")
	local regex_ascii_word = vim.regex("^[[:alnum:][:punct:]]\\+")
	local regex_last_char = vim.regex(".$")
	local regex_word_boundary = vim.regex("[[:alnum:][:punct:][:space:]　]")

	local words = {}
	local i = 0
	while i < #line do
		local rest = string.sub(line, i + 1)
		local _, spaces = regex_spaces:match_str(rest)
		local _, len = regex_ascii_word:match_str(rest)
		if spaces then
			i = i + spaces
		elseif len then
			local word = string.sub(rest, 1, len)
			local x = regex_last_char:match_str(word)
			table.insert(words, { head = i, tail = i + x })
			i = i + len
		else
			-- 日本語などの非ASCII文字の連続をbudouxのセグメントに分割する
			local run_end = regex_word_boundary:match_str(rest)
			local run = run_end and string.sub(rest, 1, run_end) or rest
			-- budouxは不正なUTF-8に対して空を返すので、runごと1つのWORDとして扱い無限ループを防ぐ
			local segments = M.parse_japanese(run)
			if #segments == 0 then
				segments = { run }
			end
			for _, segment in ipairs(segments) do
				-- NUL文字などにはvim.regexがマッチしないので、1バイト文字として数える
				local x = regex_last_char:match_str(segment) or #segment - 1
				table.insert(words, { head = i, tail = i + x })
				i = i + #segment
			end
		end
	end
	return words
end

return M
