-- The live theme: base16 palette from the current theme pack
-- (~/.local/state/theme/current/nvim.lua, path set by Nix in init.lua).
local ok, theme = pcall(dofile, vim.g.nix_theme_file)
if not ok or type(theme) ~= "table" then
  vim.cmd.colorscheme "habamax"
  return
end

vim.o.background = theme.polarity
require("mini.base16").setup { palette = theme.palette, use_cterm = true }
vim.g.colors_name = "theme-" .. theme.name
