-- Catppuccin Mocha, with the desktop accent (from mocha-theme) on the UI bits
-- that use an accent colour: cursor line number, borders, current mode, matches.
local ok, accent = pcall(require, "config.mocha-accent")
if not ok then
  accent = { name = "mauve" }
end

return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1000,
    opts = {
      flavour = "mocha",
      transparent_background = false,
      term_colors = true,
      integrations = {
        blink_cmp = true,
        flash = true,
        gitsigns = true,
        mason = true,
        mini = { enabled = true },
        noice = true,
        notify = true,
        snacks = { enabled = true },
        which_key = true,
      },
      custom_highlights = function(c)
        local a = c[accent.name] or c.mauve
        return {
          CursorLineNr = { fg = a, style = { "bold" } },
          FloatBorder = { fg = a, bg = c.mantle },
          WinSeparator = { fg = c.surface1 },
          Visual = { bg = c.surface1 },
          Search = { fg = c.crust, bg = a },
          IncSearch = { fg = c.crust, bg = c.peach },
          SnacksPickerBorder = { fg = a, bg = c.mantle },
          SnacksPickerTitle = { fg = c.crust, bg = a, style = { "bold" } },
          SnacksDashboardHeader = { fg = a },
        }
      end,
    },
  },
  {
    "LazyVim/LazyVim",
    opts = { colorscheme = "catppuccin" },
  },
}
