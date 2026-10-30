-- Nix integration, imported last by lazy_setup.lua. Everything AstroNvim
-- would install at runtime comes from Nix instead (modules/home/editor/astronvim):
-- plugins, treesitter grammars, language servers, formatters, linters.

-- The languages: set from languages.nix (servers, formatters and linters to
-- switch on, servers whose own formatting is off)
local languages = vim.g.nix_languages
  or {
    servers = {},
    formatters = {},
    linters = {},
    formattingDisabled = {},
    formatterFiletypes = {},
    serverCommands = {},
  }

-- servers started by an absolute path (languages.nix: serverCommands)
local server_config = {}
for name, command in pairs(languages.serverCommands) do
  server_config[name] = { cmd = { command } }
end

local managed_by_nix = function()
  vim.notify(
    "Plugins, tools and AstroNvim are managed by Nix.\nUpdate everything: nh home switch --update",
    vim.log.levels.INFO,
    { title = "Nix" }
  )
end

---@type LazySpec
return {
  -- Mason installs tools at runtime; Nix provides them on nvim's PATH.
  { "mason-org/mason.nvim", enabled = false },
  { "mason-org/mason-lspconfig.nvim", enabled = false },
  { "jay-babu/mason-null-ls.nvim", enabled = false },
  { "jay-babu/mason-nvim-dap.nvim", enabled = false },
  { "WhoIsSethDaniel/mason-tool-installer.nvim", enabled = false },

  -- Language servers (languages.nix); `formattingDisabled`: a server whose
  -- formatting would run next to the formatter of the language
  {
    "AstroNvim/astrolsp",
    opts = {
      servers = languages.servers,
      config = server_config,
      formatting = { disabled = languages.formattingDisabled },
    },
  },

  -- Formatters and linters (none-ls, languages.nix)
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
      local custom = { autopep8 = autopep8 }
      local sources = {}
      for _, name in ipairs(languages.formatters) do
        local source = custom[name] or b.formatting[name]
        local filetypes = languages.formatterFiletypes[name]
        if filetypes then source = source.with { filetypes = filetypes } end
        table.insert(sources, source)
      end
      for _, name in ipairs(languages.linters) do
        table.insert(sources, b.diagnostics[name])
      end
      opts.sources = require("astrocore").list_insert_unique(opts.sources, sources)
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
      local function enable(buf)
        vim.schedule(function() ts.enable(buf) end)
      end
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

  -- Updates are Nix's job: say so instead of failing on the read-only plugin
  -- directory (:AstroUpdate, <Leader>pi/pS/pu/pU/pa)
  {
    "AstroNvim/astrocore",
    opts = {
      commands = {
        AstroUpdate = { managed_by_nix, desc = "Update (managed by Nix)" },
      },
      mappings = {
        n = {
          ["<Leader>pi"] = { managed_by_nix, desc = "Plugins Install (Nix)" },
          ["<Leader>pS"] = { managed_by_nix, desc = "Plugins Sync (Nix)" },
          ["<Leader>pu"] = { managed_by_nix, desc = "Plugins Check Updates (Nix)" },
          ["<Leader>pU"] = { managed_by_nix, desc = "Plugins Update (Nix)" },
          ["<Leader>pa"] = { managed_by_nix, desc = "Update (Nix)" },
        },
      },
    },
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
            callback = function()
              vim.schedule(function() vim.cmd.colorscheme "theme" end)
            end,
          },
        },
      },
    },
  },
}
