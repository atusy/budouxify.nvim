# budouxify.nvim

Empower Neovim with [google/budoux](https://github.com/google/budoux), the machine learning powered line break organizer tool.

## Installation

With lazy.nvim

`````lua
{
  {"https://github.com/atusy/budoux.lua"},
  {
    "https://github.com/atusy/budouxify.nvim",
    config = function()
      vim.keymap.set("n", "W", function()
          local pos = require("budouxify.motion").find_forward({
              head = true,
          })
          if pos then
              vim.api.nvim_win_set_cursor(0, { pos.row, pos.col })
          end
      end)
      vim.keymap.set("n", "E", function()
          local pos = require("budouxify.motion").find_forward({
              head = false,
          })
          if pos then
              vim.api.nvim_win_set_cursor(0, { pos.row, pos.col })
          end
      end)
      vim.keymap.set("n", "B", function()
          local pos = require("budouxify.motion").find_backward({
              head = true,
          })
          if pos then
              vim.api.nvim_win_set_cursor(0, { pos.row, pos.col })
          end
      end)
      vim.keymap.set("n", "gE", function()
          local pos = require("budouxify.motion").find_backward({
              head = false,
          })
          if pos then
              vim.api.nvim_win_set_cursor(0, { pos.row, pos.col })
          end
      end)
      -- text objects: iW / aW
      vim.keymap.set({ "x", "o" }, "iW", function()
          require("budouxify.textobject").select({ inner = true })
      end)
      vim.keymap.set({ "x", "o" }, "aW", function()
          require("budouxify.textobject").select({ inner = false })
      end)
    end
  },
}
`````

## Text objects

`iW` and `aW` are modelled on Vim's built-in ones, but a WORD in Japanese
text is a [budoux](https://github.com/google/budoux) segment, so `diW` on
`今日は天気です。` with the cursor on `天` deletes `天気です。`.

- `iW` selects the WORD under the cursor, or the run of blanks when the
  cursor is on a blank.
- `aW` also selects the trailing blanks (or the leading ones when there are
  none), and on a blank selects the blanks together with the following WORD
  (or just the blanks when nothing follows on the line).
- A count selects that many objects, e.g. `d2aW`.

Differences from Vim: both stay within the current line, and in Visual mode
they reselect the object under the cursor instead of extending the area.

`require("budouxify.textobject").find({ inner = true })` returns the range as
`{ start = { row, col }, finish = { row, col } }` (byte offsets, both ends
inclusive), or `nil` on an empty line, if you want to build your own mapping.
