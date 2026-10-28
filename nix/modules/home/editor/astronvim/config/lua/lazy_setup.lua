require("lazy").setup({
  {
    "AstroNvim/AstroNvim",
    version = "^5", -- Remove version tracking to elect for nightly AstroNvim
    import = "astronvim.plugins",
    opts = { -- AstroNvim options must be set here with the `import` key
      mapleader = " ", -- This ensures the leader key must be configured before Lazy is set up
      maplocalleader = ",", -- This ensures the localleader key must be configured before Lazy is set up
      icons_enabled = true, -- Set to false to disable icons (if no Nerd Font is available)
      -- Nix pins every plugin (flake.lock), not lazy.nvim
      pin_plugins = false,
      update_notifications = false,
    },
  },
  { import = "community" },
  { import = "plugins" },
  -- Nix integration (Mason off, language servers and formatters from Nix,
  -- live theme); last, so it overrides the specs above
  { import = "nix" },
} --[[@as LazySpec]], {
  -- Configure any other `lazy.nvim` configuration options here
  -- Every plugin is built by Nix (modules/home/editor/astronvim) and loaded
  -- from one directory; lazy.nvim never downloads or updates anything.
  dev = { path = vim.g.nix_lazy_plugins, patterns = { "" }, fallback = false },
  install = { missing = false, colorscheme = { "theme", "habamax" } },
  checker = { enabled = false },
  change_detection = { enabled = false },
  rocks = { enabled = false },
  lockfile = vim.fn.stdpath "state" .. "/lazy-lock.json",
  ui = { backdrop = 100 },
  performance = {
    -- Keep the paths Nix's Neovim wrapper sets up (see nixCats' lazy.nvim notes)
    reset_packpath = false,
    rtp = {
      reset = false,
      -- disable some rtp plugins, add more to your liking
      disabled_plugins = {
        "gzip",
        "netrwPlugin",
        "tarPlugin",
        "tohtml",
        "zipPlugin",
      },
    },
  },
} --[[@as LazyConfig]])
