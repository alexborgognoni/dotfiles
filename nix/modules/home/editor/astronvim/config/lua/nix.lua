-- Nix integration, imported last by lazy_setup.lua. Everything AstroNvim
-- would install at runtime comes from Nix instead (modules/home/editor/astronvim):
-- plugins, treesitter grammars, language servers, formatters.

---@type LazySpec
return {
  -- Mason installs tools at runtime; Nix provides them on nvim's PATH.
  { "mason-org/mason.nvim", enabled = false },
  { "mason-org/mason-lspconfig.nvim", enabled = false },
  { "jay-babu/mason-null-ls.nvim", enabled = false },
  { "jay-babu/mason-nvim-dap.nvim", enabled = false },
  { "WhoIsSethDaniel/mason-tool-installer.nvim", enabled = false },

  -- Language servers (what mason.lua used to install, plus nix, bash, json, yaml)
  {
    "AstroNvim/astrolsp",
    opts = {
      servers = { "bashls", "eslint", "jsonls", "lua_ls", "nixd", "pyright", "ts_ls", "yamlls" },
    },
  },

  -- Formatters (none-ls); shellcheck diagnostics come through bashls
  {
    "nvimtools/none-ls.nvim",
    opts = function(_, opts)
      local null_ls = require "null-ls"
      local h = require "null-ls.helpers"
      local b = null_ls.builtins
      -- none-ls dropped its autopep8 builtin (mason-null-ls used to provide it)
      local autopep8 = h.make_builtin {
        name = "autopep8",
        method = null_ls.methods.FORMATTING,
        filetypes = { "python" },
        generator_opts = { command = "autopep8", args = { "-" }, to_stdin = true },
        factory = h.formatter_factory,
      }
      opts.sources = require("astrocore").list_insert_unique(opts.sources, {
        autopep8,
        b.formatting.nixfmt,
        b.formatting.prettierd,
        b.formatting.shfmt,
        b.formatting.stylua,
        b.formatting.yamlfmt,
      })
    end,
  },

  -- Grammars are built by Nix and live in the plugin directory: nvim-treesitter
  -- treats it as its install dir, AstroCore never installs anything.
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { install_dir = vim.g.nix_lazy_plugins .. "/nvim-treesitter" },
    config = function(_, opts)
      require("nvim-treesitter").setup(opts)
      -- AstroCore caches the installed parsers when the plugin loads, before
      -- this install_dir applies; refresh it now that the parsers are visible.
      local ts = require "astrocore.treesitter"
      ts.installed(true)
      -- AstroCore's own FileType handler can run before this; enable through
      -- it again (same checks: parser, feature toggles, large files).
      local function enable(buf) vim.schedule(function() ts.enable(buf) end) end
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("nix_treesitter", { clear = true }),
        callback = function(args) enable(args.buf) end,
      })
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype ~= "" then enable(buf) end
      end
    end,
  },
  {
    "AstroNvim/astrocore",
    opts = function(_, opts)
      opts.treesitter.ensure_installed = {}
      opts.treesitter.auto_install = false
    end,
  },

  -- Built by Nix with its web app included
  { "iamcco/markdown-preview.nvim", build = false },

  -- Colors follow the live theme pack (colors/theme.lua); the `theme`
  -- command sends SIGUSR1 to open editors to switch them instantly.
  { "nvim-mini/mini.base16", lazy = true },
  {
    "AstroNvim/astroui",
    opts = { colorscheme = "theme" },
  },
  {
    "AstroNvim/astrocore",
    opts = {
      autocmds = {
        nix_theme_reload = {
          {
            event = "Signal",
            pattern = "SIGUSR1",
            desc = "Reload the live theme",
            callback = function() vim.schedule(function() vim.cmd.colorscheme "theme" end) end,
          },
        },
      },
    },
  },
}
