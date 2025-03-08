# budouxify.nvim

Empower Neovim with [google/budoux](https://github.com/google/budoux), the machine learning powered line break organizer tool.

## Installation

With lazy.nvim

`````lua
{
  {"https://github.com/atusy/budoux.lua"},
  {
    "https://github.com/atusy/budouxify.nvim"
    config = function()
      vim.keymap.set("n", "W", function()
          local pos = require("budouxify.motion").find_forward({
              row = vim.api.nvim_win_get_cursor(0)[1],
              col = vim.api.nvim_win_get_cursor(0)[2],
              head = true,
          })
          if pos then
              vim.api.nvim_win_set_cursor(0, { pos.row, pos.col })
          end
      end)
      vim.keymap.set("n", "E", function()
          local pos = require("budouxify.motion").find_forward({
              row = vim.api.nvim_win_get_cursor(0)[1],
              col = vim.api.nvim_win_get_cursor(0)[2],
              head = false,
          })
          if pos then
              vim.api.nvim_win_set_cursor(0, { pos.row, pos.col })
          end
      end)
    end
  },
}
`````
