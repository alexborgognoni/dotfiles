# Colors follow the live theme pack (modules/home/theme.nix): the palette is
# read from ~/.local/state/theme/current/nvim.lua at startup and again when
# the `theme` command sends SIGUSR1, so open editors switch instantly.
{ config, ... }:
{
  programs.nixvim = {
    plugins.mini = {
      enable = true;
      mockDevIcons = true;
      modules.icons = { };
    };

    extraConfigLuaPre = ''
      local theme_file = "${config.my.themeState}/current/nvim.lua"

      local function apply_theme()
        local ok, theme = pcall(dofile, theme_file)
        if not ok or type(theme) ~= "table" then
          return
        end
        vim.o.background = theme.polarity
        require("mini.base16").setup({ palette = theme.palette, use_cterm = true })
        vim.g.colors_name = "theme-" .. theme.name
        vim.api.nvim_exec_autocmds("ColorScheme", { pattern = vim.g.colors_name, modeline = false })
      end

      apply_theme()

      vim.api.nvim_create_autocmd("Signal", {
        pattern = "SIGUSR1",
        callback = function()
          vim.schedule(apply_theme)
        end,
      })
    '';
  };
}
